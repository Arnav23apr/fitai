import Foundation
import UIKit

// MARK: - Public message types (used by CoachService and other callers)

nonisolated struct MessagePart: Codable, Sendable {
    let type: String
    let text: String?
    let image: String?

    init(text: String) {
        self.type = "text"
        self.text = text
        self.image = nil
    }

    init(imageBase64: String) {
        self.type = "image"
        self.text = nil
        self.image = imageBase64
    }
}

nonisolated struct ChatAPIMessage: Codable, Sendable {
    let role: String
    let parts: [MessagePart]
    let id: String

    init(role: String, text: String, id: String = UUID().uuidString) {
        self.role = role
        self.parts = [MessagePart(text: text)]
        self.id = id
    }

    init(role: String, parts: [MessagePart], id: String = UUID().uuidString) {
        self.role = role
        self.parts = parts
        self.id = id
    }
}

// MARK: - Gemini API types

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let systemInstruction: GeminiContent?
    let generationConfig: GeminiGenerationConfig?
}

private struct GeminiContent: Codable {
    let role: String?
    let parts: [GeminiPart]

    init(role: String? = nil, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }
}

private struct GeminiPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?

    init(text: String) {
        self.text = text
        self.inlineData = nil
    }

    init(imageBase64: String, mimeType: String = "image/jpeg") {
        self.text = nil
        self.inlineData = GeminiInlineData(mimeType: mimeType, data: imageBase64)
    }
}

private struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String
}

private struct GeminiGenerationConfig: Encodable {
    let temperature: Double?
    let maxOutputTokens: Int?
    let responseMimeType: String?
    let responseSchema: [String: AnyCodable]?
    let responseModalities: [String]?

    init(temperature: Double? = nil, maxOutputTokens: Int? = nil, responseMimeType: String? = nil, responseSchema: [String: AnyCodable]? = nil, responseModalities: [String]? = nil) {
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.responseMimeType = responseMimeType
        self.responseSchema = responseSchema
        self.responseModalities = responseModalities
    }
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
    let error: GeminiError?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent?
}

private struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]?
}

private struct GeminiResponsePart: Decodable {
    let text: String?
    let inlineData: GeminiResponseInlineData?
}

private struct GeminiResponseInlineData: Decodable {
    let mimeType: String?
    let data: String?
}

private struct GeminiError: Decodable {
    let message: String?
    let code: Int?
}

// MARK: - AIService (Gemini)

class AIService {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let model = "gemini-2.5-flash-lite"
    // Nano Banana Pro (gemini-3-pro-image-preview) is ~$0.12/image vs Nano Banana
    // 2.5 at ~$0.039. We tested 2.5 and it failed to preserve the user's pose +
    // likeness on transformations, so we're sticking with Pro for quality. Cost
    // is controlled via per-user generation limits in TransformationLimiter.
    private let imageModel = "gemini-3-pro-image-preview"

    /// Simple per-day rate limiter to prevent runaway API costs.
    /// Bumped to 500/day to avoid blocking heavy testing during dev. The
    /// real budget gate is `FreeUsageTracker` for free users; this is a
    /// last-resort runaway-cost protection.
    private static let dailyLimitKey = "ai_daily_request_count"
    private static let dailyLimitDateKey = "ai_daily_request_date"
    private static let maxDailyRequests = 500

    init() {
        self.apiKey = Config.GEMINI_API_KEY
    }

    /// Check and increment daily request counter. Throws if limit exceeded.
    private func checkRateLimit() throws {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        let storedDate = defaults.object(forKey: Self.dailyLimitDateKey) as? Date ?? .distantPast

        if Calendar.current.startOfDay(for: storedDate) != today {
            defaults.set(0, forKey: Self.dailyLimitKey)
            defaults.set(today, forKey: Self.dailyLimitDateKey)
        }

        let count = defaults.integer(forKey: Self.dailyLimitKey)
        if count >= Self.maxDailyRequests {
            throw AIError.serverError("Daily limit reached. Please try again tomorrow.")
        }
        defaults.set(count + 1, forKey: Self.dailyLimitKey)
    }

    /// Retry a throwing async closure with exponential backoff on transient errors (429, 5xx).
    private func withRetry<T>(maxAttempts: Int = 3, _ work: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await work()
            } catch let error as AIError {
                lastError = error
                // Only retry on rate-limit or server errors
                if case .serverError(let msg) = error,
                   (msg.contains("429") || msg.contains("500") || msg.contains("503")) {
                    let delay = Double(1 << attempt) // 1s, 2s, 4s
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw error
            } catch {
                lastError = error
                let delay = Double(1 << attempt)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? AIError.networkError
    }

    // MARK: - Scan Analysis

    /// Multi-image variant. Used by physique scan when the user has uploaded
    /// both a front and back photo so the AI can see all muscle groups.
    /// Pass images in display order (front first, back second). Empty array
    /// throws — caller must guarantee at least one image.
    func analyzeImagesWithSchema(imagesBase64: [String], systemPrompt: String, userPrompt: String) async throws -> [String: Any] {
        guard !imagesBase64.isEmpty else { throw AIError.decodingError }

        let schema: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "overallScore": ["type": "number"],
                "strongPoints": ["type": "array", "items": ["type": "string"]],
                "weakPoints": ["type": "array", "items": ["type": "string"]],
                "summary": ["type": "string"],
                "recommendations": ["type": "array", "items": ["type": "string"]],
                "potentialRating": ["type": "number"],
                "muscleMassRating": ["type": "string"],
                "visibleMuscleGroups": ["type": "array", "items": ["type": "string"]],
                "muscleScores": ["type": "object", "properties": [
                    "chest": ["type": "number"],
                    "shoulders": ["type": "number"],
                    "back": ["type": "number"],
                    "arms": ["type": "number"],
                    "legs": ["type": "number"],
                    "core": ["type": "number"],
                    "glutes": ["type": "number"]
                ] as [String: Any]]
            ]),
            "required": AnyCodable([
                "overallScore", "strongPoints", "weakPoints", "summary",
                "recommendations", "potentialRating", "muscleMassRating",
                "visibleMuscleGroups", "muscleScores"
            ])
        ]

        let systemContent = GeminiContent(role: nil, parts: [GeminiPart(text: systemPrompt)])

        var userParts: [GeminiPart] = imagesBase64.map { GeminiPart(imageBase64: $0) }
        userParts.append(GeminiPart(text: userPrompt))
        let userContent = GeminiContent(role: "user", parts: userParts)

        let genConfig = GeminiGenerationConfig(
            temperature: 0.4,
            maxOutputTokens: 2048,
            responseMimeType: "application/json",
            responseSchema: schema
        )

        let request = GeminiRequest(
            contents: [userContent],
            systemInstruction: systemContent,
            generationConfig: genConfig
        )

        try checkRateLimit()
        let responseText = try await withRetry { try await self.callGemini(request: request) }

        guard let data = responseText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.decodingError
        }

        return json
    }

    func analyzeImageWithSchema(imageBase64: String, systemPrompt: String, userPrompt: String) async throws -> [String: Any] {
        let schema: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "overallScore": ["type": "number"],
                "strongPoints": ["type": "array", "items": ["type": "string"]],
                "weakPoints": ["type": "array", "items": ["type": "string"]],
                "summary": ["type": "string"],
                "recommendations": ["type": "array", "items": ["type": "string"]],
                "potentialRating": ["type": "number"],
                "muscleMassRating": ["type": "string"],
                "visibleMuscleGroups": ["type": "array", "items": ["type": "string"]],
                "muscleScores": ["type": "object", "properties": [
                    "chest": ["type": "number"],
                    "shoulders": ["type": "number"],
                    "back": ["type": "number"],
                    "arms": ["type": "number"],
                    "legs": ["type": "number"],
                    "core": ["type": "number"],
                    "glutes": ["type": "number"]
                ] as [String: Any]]
            ]),
            "required": AnyCodable([
                "overallScore",
                "strongPoints",
                "weakPoints",
                "summary",
                "recommendations",
                "potentialRating",
                "muscleMassRating",
                "visibleMuscleGroups",
                "muscleScores"
            ])
        ]

        let systemContent = GeminiContent(role: nil, parts: [GeminiPart(text: systemPrompt)])

        let userContent = GeminiContent(role: "user", parts: [
            GeminiPart(imageBase64: imageBase64),
            GeminiPart(text: userPrompt)
        ])

        let genConfig = GeminiGenerationConfig(
            temperature: 0.4,
            maxOutputTokens: 2048,
            responseMimeType: "application/json",
            responseSchema: schema
        )

        let request = GeminiRequest(
            contents: [userContent],
            systemInstruction: systemContent,
            generationConfig: genConfig
        )

        try checkRateLimit()
        let responseText = try await withRetry { try await self.callGemini(request: request) }

        guard let data = responseText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.decodingError
        }

        return json
    }

    // MARK: - Chat

    func chat(messages: [ChatAPIMessage]) async throws -> String {
        var systemParts: [GeminiPart] = []
        var contents: [GeminiContent] = []

        for msg in messages {
            var parts: [GeminiPart] = []
            for part in msg.parts {
                if let text = part.text {
                    parts.append(GeminiPart(text: text))
                } else if let image = part.image {
                    parts.append(GeminiPart(imageBase64: image))
                }
            }

            if msg.role == "system" {
                systemParts.append(contentsOf: parts)
            } else {
                let role = msg.role == "assistant" ? "model" : "user"
                contents.append(GeminiContent(role: role, parts: parts))
            }
        }

        // Ensure conversation starts with a user message
        if contents.isEmpty {
            throw AIError.emptyResponse
        }

        let systemInstruction = systemParts.isEmpty ? nil : GeminiContent(role: nil, parts: systemParts)

        let genConfig = GeminiGenerationConfig(
            temperature: 0.7,
            maxOutputTokens: 1024,
            responseMimeType: nil,
            responseSchema: nil
        )

        let request = GeminiRequest(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: genConfig
        )

        try checkRateLimit()
        return try await withRetry { try await self.callGemini(request: request) }
    }

    // MARK: - Image + structured JSON
    //
    // Same as `analyzeImageWithSchema` but caller-provides the schema and
    // gets back the raw JSON string. Used by `WeightOCRService` for gym-
    // photo scene understanding (custom schema per call site).

    func analyzeImageWithSchemaJSON(imageBase64: String, systemPrompt: String, userPrompt: String, schema: [String: AnyCodable]) async throws -> String {
        let systemContent = GeminiContent(role: nil, parts: [GeminiPart(text: systemPrompt)])
        let userContent = GeminiContent(role: "user", parts: [
            GeminiPart(imageBase64: imageBase64),
            GeminiPart(text: userPrompt)
        ])
        let genConfig = GeminiGenerationConfig(
            temperature: 0.4,
            maxOutputTokens: 1024,
            responseMimeType: "application/json",
            responseSchema: schema
        )
        let request = GeminiRequest(
            contents: [userContent],
            systemInstruction: systemContent,
            generationConfig: genConfig
        )
        try checkRateLimit()
        return try await withRetry { try await self.callGemini(request: request) }
    }

    // MARK: - Structured JSON chat
    //
    // Same as `chat()` but forces Gemini into JSON-output mode with the
    // caller's schema. Use this for any flow where the response needs to
    // decode into a specific shape (template generation, plan edits, etc.) —
    // unstructured chat() can wrap output in markdown / prose, which the
    // PlanModificationService parser used to choke on.

    func chatJSON(systemPrompt: String, userPrompt: String, schema: [String: AnyCodable]) async throws -> String {
        let systemContent = GeminiContent(role: nil, parts: [GeminiPart(text: systemPrompt)])
        let userContent = GeminiContent(role: "user", parts: [GeminiPart(text: userPrompt)])

        let genConfig = GeminiGenerationConfig(
            temperature: 0.6,
            maxOutputTokens: 2048,
            responseMimeType: "application/json",
            responseSchema: schema
        )

        let request = GeminiRequest(
            contents: [userContent],
            systemInstruction: systemContent,
            generationConfig: genConfig
        )

        try checkRateLimit()
        return try await withRetry { try await self.callGemini(request: request) }
    }

    // MARK: - Image Generation (Nano Banana Pro)

    func generateImage(prompt: String, size: String = "1024x1024") async throws -> UIImage {
        let userContent = GeminiContent(role: "user", parts: [
            GeminiPart(text: prompt)
        ])

        let genConfig = GeminiGenerationConfig(
            responseModalities: ["IMAGE"]
        )

        let request = GeminiRequest(
            contents: [userContent],
            systemInstruction: nil,
            generationConfig: genConfig
        )

        try checkRateLimit()
        return try await withRetry { try await self.callGeminiImage(request: request) }
    }

    // MARK: - Image Edit (Nano Banana Pro)

    func editImage(prompt: String, imageBase64: String, aspectRatio: String = "3:4") async throws -> UIImage {
        let userContent = GeminiContent(role: "user", parts: [
            GeminiPart(imageBase64: imageBase64),
            GeminiPart(text: prompt)
        ])

        let genConfig = GeminiGenerationConfig(
            responseModalities: ["IMAGE"]
        )

        let request = GeminiRequest(
            contents: [userContent],
            systemInstruction: nil,
            generationConfig: genConfig
        )

        try checkRateLimit()
        return try await withRetry { try await self.callGeminiImage(request: request) }
    }

    // MARK: - Core Gemini Image Call (Nano Banana Pro)

    private func callGeminiImage(request: GeminiRequest) async throws -> UIImage {
        let url = URL(string: "\(baseURL)/\(imageModel):generateContent?key=\(apiKey)")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        #if DEBUG
        print("[AIService/NanaBanana] POST \(imageModel):generateContent")
        #endif

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError
        }

        #if DEBUG
        print("[AIService/NanaBanana] Status: \(httpResponse.statusCode)")
        #endif

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            if let errorData = errorText.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.serverError("Image generation: \(message)")
            }
            throw AIError.serverError("Image generation error (\(httpResponse.statusCode))")
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let error = geminiResponse.error {
            throw AIError.serverError("Image generation: \(error.message ?? "Unknown error")")
        }

        // Extract image from response parts
        guard let parts = geminiResponse.candidates?.first?.content?.parts else {
            throw AIError.emptyResponse
        }

        for part in parts {
            if let inlineData = part.inlineData,
               let base64String = inlineData.data,
               let imageData = Data(base64Encoded: base64String),
               let image = UIImage(data: imageData) {
                return image
            }
        }

        throw AIError.serverError("No image returned in response")
    }

    // MARK: - Core Gemini Text Call

    private func callGemini(request: GeminiRequest) async throws -> String {
        let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        #if DEBUG
        if let bodyData = urlRequest.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[AIService/Gemini] POST \(model):generateContent")
            print("[AIService/Gemini] Body (truncated): \(bodyString.prefix(500))...")
        }
        #endif

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError
        }

        #if DEBUG
        let responseText = String(data: data, encoding: .utf8) ?? "[binary]"
        print("[AIService/Gemini] Status: \(httpResponse.statusCode)")
        print("[AIService/Gemini] Response (truncated): \(responseText.prefix(1000))")
        #endif

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            if let errorData = errorText.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.serverError("Gemini: \(message)")
            }
            throw AIError.serverError("\(httpResponse.statusCode) Gemini error: \(String(errorText.prefix(200)))")
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let error = geminiResponse.error {
            throw AIError.serverError("Gemini: \(error.message ?? "Unknown error")")
        }

        guard let text = geminiResponse.candidates?.first?.content?.parts?.first?.text else {
            throw AIError.emptyResponse
        }

        return text
    }

    // MARK: - Utility

    nonisolated static func imageToBase64(_ image: UIImage, maxDimension: CGFloat = 800) -> String? {
        let size = image.size
        let scale: CGFloat
        if max(size.width, size.height) > maxDimension {
            scale = maxDimension / max(size.width, size.height)
        } else {
            scale = 1.0
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resized.jpegData(compressionQuality: 0.7)?.base64EncodedString()
    }
}

// MARK: - AnyCodable (kept for schema encoding)

nonisolated struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let strVal = try? container.decode(String.self) {
            value = strVal
        } else if let arrVal = try? container.decode([AnyCodable].self) {
            value = arrVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            value = "" as Any
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let strVal = value as? String {
            try container.encode(strVal)
        } else if let arrVal = value as? [Any] {
            try container.encode(arrVal.map { AnyCodable($0) })
        } else if let dictVal = value as? [String: Any] {
            try container.encode(dictVal.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - Errors

nonisolated enum AIError: Error, Sendable, LocalizedError {
    case invalidURL
    case networkError
    case serverError(String)
    case emptyResponse
    case decodingError

    nonisolated var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .networkError: return "Network error occurred"
        case .serverError(let msg): return msg
        case .emptyResponse: return "No response received"
        case .decodingError: return "Failed to process response"
        }
    }
}
