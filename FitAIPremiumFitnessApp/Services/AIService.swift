import Foundation
import UIKit

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

nonisolated struct ChatRequest: Codable, Sendable {
    let messages: [ChatAPIMessage]
}

nonisolated enum LLMContentPart: Codable, Sendable {
    case text(String)
    case image(String)

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .text)
        case .image(let value):
            try container.encode("image", forKey: .type)
            try container.encode(value, forKey: .image)
        }
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "image" {
            self = .image(try container.decode(String.self, forKey: .image))
        } else {
            self = .text(try container.decode(String.self, forKey: .text))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, text, image
    }
}

nonisolated struct LLMMessage: Codable, Sendable {
    let role: String
    let content: [LLMContentPart]
}

nonisolated struct LLMTextRequest: Codable, Sendable {
    let messages: [LLMMessage]
}

nonisolated struct LLMTextResponse: Codable, Sendable {
    let completion: String
}

nonisolated struct LLMContentPart2: Codable, Sendable {
    let type: String
    let text: String?
    let image: String?

    init(text: String) {
        self.type = "text"
        self.text = text
        self.image = nil
    }

    init(imageDataURI: String) {
        self.type = "image"
        self.text = nil
        self.image = imageDataURI
    }
}

nonisolated struct LLMObjectMessage: Codable, Sendable {
    let role: String
    let content: LLMObjectContent
}

nonisolated enum LLMObjectContent: Codable, Sendable {
    case text(String)
    case parts([LLMContentPart2])

    nonisolated func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let str):
            var container = encoder.singleValueContainer()
            try container.encode(str)
        case .parts(let parts):
            var container = encoder.singleValueContainer()
            try container.encode(parts)
        }
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .text(str)
        } else {
            self = .parts(try container.decode([LLMContentPart2].self))
        }
    }
}

nonisolated struct LLMObjectRequest: Codable, Sendable {
    let messages: [LLMObjectMessage]
    let schema: [String: AnyCodable]
}

nonisolated struct LLMObjectResponse: Codable, Sendable {
    let object: [String: AnyCodable]
}

nonisolated struct AnyCodable: Codable, Sendable {
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

nonisolated struct ImageGenerateRequest: Codable, Sendable {
    let prompt: String
    let size: String?
}

nonisolated struct ImageGenerateResponse: Codable, Sendable {
    let image: ImageData
    let size: String

    nonisolated struct ImageData: Codable, Sendable {
        let base64Data: String
        let mimeType: String
    }
}

nonisolated struct ImageEditRequest: Codable, Sendable {
    let prompt: String
    let images: [ImageInput]
    let aspectRatio: String?

    nonisolated struct ImageInput: Codable, Sendable {
        let type: String
        let image: String
    }
}

nonisolated struct ImageEditResponse: Codable, Sendable {
    let image: ImageData

    nonisolated struct ImageData: Codable, Sendable {
        let base64Data: String
        let mimeType: String
        let aspectRatio: String
    }
}

class AIService {
    private let chatURL: URL
    private let llmObjectURL: URL
    private let imageGenerateURL: URL
    private let imageEditURL: URL

    init() {
        let toolkitBaseURL = URL(string: Config.EXPO_PUBLIC_TOOLKIT_URL)!
        self.chatURL = toolkitBaseURL.appending(path: "agent/chat")
        self.llmObjectURL = toolkitBaseURL.appending(path: "llm/object")
        self.imageGenerateURL = toolkitBaseURL.appending(path: "images/generate")
        self.imageEditURL = toolkitBaseURL.appending(path: "images/edit")
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
                    "core": ["type": "number"]
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

        // Combine system and user prompts into a single text instruction
        let combinedPrompt = systemPrompt + "\n\n" + userPrompt

        // Create a single user message with image first, then text (matching working implementation)
        let userMsg = LLMObjectMessage(
            role: "user",
            content: .parts([
                LLMContentPart2(imageDataURI: "data:image/jpeg;base64," + imageBase64),
                LLMContentPart2(text: combinedPrompt)
            ])
        )

        let body = LLMObjectRequest(messages: [userMsg], schema: schema)
        let response = try await postObject(body: body)

        return response.mapValues { $0.value }
    }

    func chat(messages: [ChatAPIMessage]) async throws -> String {
        let body = ChatRequest(messages: messages)
        return try await postChat(body: body)
    }

    func generateImage(prompt: String, size: String = "1024x1024") async throws -> UIImage {
        var request = URLRequest(url: imageGenerateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body = ImageGenerateRequest(prompt: prompt, size: size)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.serverError("Image generation failed (\(httpResponse.statusCode)): \(extractErrorMessage(from: errorText))")
        }

        let decoded = try JSONDecoder().decode(ImageGenerateResponse.self, from: data)
        guard let imageData = Data(base64Encoded: decoded.image.base64Data),
              let image = UIImage(data: imageData) else {
            throw AIError.decodingError
        }
        return image
    }

    func editImage(prompt: String, imageBase64: String, aspectRatio: String = "3:4") async throws -> UIImage {
        var request = URLRequest(url: imageEditURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body = ImageEditRequest(
            prompt: prompt,
            images: [.init(type: "image", image: imageBase64)],
            aspectRatio: aspectRatio
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.serverError("Image editing failed (\(httpResponse.statusCode)): \(extractErrorMessage(from: errorText))")
        }

        let decoded = try JSONDecoder().decode(ImageEditResponse.self, from: data)
        guard let imageData = Data(base64Encoded: decoded.image.base64Data),
              let image = UIImage(data: imageData) else {
            throw AIError.decodingError
        }
        return image
    }

    private func postObject(body: LLMObjectRequest) async throws -> [String: AnyCodable] {
        var request = URLRequest(url: llmObjectURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        request.httpBody = try encoder.encode(body)

        // Log request details (excluding base64 image for brevity)
        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            let truncated = bodyString.prefix(500)
            print("[AIService] POST \(llmObjectURL.absoluteString)")
            print("[AIService] Request body (truncated): \(truncated)...")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError
        }

        // Log response details
        let responseText = String(data: data, encoding: .utf8) ?? "[binary data]"
        print("[AIService] Response status: \(httpResponse.statusCode)")
        print("[AIService] Response body: \(responseText.prefix(1000))")

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.serverError("Image analysis failed (\(httpResponse.statusCode)): \(extractErrorMessage(from: errorText))")
        }

        let decoded = try JSONDecoder().decode(LLMObjectResponse.self, from: data)
        return decoded.object
    }

    private func postChat(body: ChatRequest) async throws -> String {
        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        guard httpResponse.statusCode == 200 else {
            throw AIError.serverError("Chat failed (\(httpResponse.statusCode)): \(extractErrorMessage(from: responseText))")
        }

        let lines = responseText.components(separatedBy: "\n")
        var fullText = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("data: ") {
                let jsonPart = String(trimmed.dropFirst(6))

                if jsonPart == "[DONE]" { continue }

                guard let jsonData = jsonPart.data(using: .utf8),
                      let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let eventType = event["type"] as? String else {
                    continue
                }

                if eventType == "text-delta", let delta = event["delta"] as? String {
                    fullText += delta
                } else if eventType == "error", let message = event["message"] as? String {
                    throw AIError.serverError(message)
                }
            } else if trimmed.hasPrefix("0:") {
                let jsonPart = String(trimmed.dropFirst(2))
                if let stringData = jsonPart.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(String.self, from: stringData) {
                    fullText += decoded
                }
            } else if trimmed.hasPrefix("e:") {
                let errorPart = String(trimmed.dropFirst(2))
                if let errorData = errorPart.data(using: .utf8),
                   let errorObj = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                   let errorMessage = errorObj["message"] as? String ?? errorObj["error"] as? String {
                    throw AIError.serverError(errorMessage)
                }
            }
        }

        if fullText.isEmpty {
            if !responseText.isEmpty {
                if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = jsonObj["error"] as? String {
                        throw AIError.serverError(error)
                    }
                    if let message = jsonObj["message"] as? String {
                        throw AIError.serverError(message)
                    }
                    if let text = jsonObj["text"] as? String {
                        return text
                    }
                }
                return responseText
            }
            throw AIError.emptyResponse
        }

        return fullText
    }



    private func extractErrorMessage(from text: String) -> String {
        let trimmed = String(text.prefix(300))
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let msg = json["message"] as? String { return msg }
            if let err = json["error"] as? String { return err }
            if let detail = json["detail"] as? String { return detail }
        }
        return trimmed
    }

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
