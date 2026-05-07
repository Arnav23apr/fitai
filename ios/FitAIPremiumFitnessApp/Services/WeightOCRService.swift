import Foundation
import UIKit
import Vision

/// Photo-driven set logging: scene understanding from a single image.
///
/// Two paths:
///
/// 1. **Apple Vision OCR fast path** — for static text targets like
///    weight-stack stickers, dumbbell head labels, and machine selectors.
///    Free, on-device, ~100ms. Handles ~75% of real-world gym photos.
///
/// 2. **Gemini Flash Lite multimodal fallback** — for everything else:
///    loaded barbells (plate counting), 7-segment LED displays, ambiguous
///    scenes. Reads the FULL scene: equipment type, exercise inference,
///    weight calculation including bar weight. ~$0.00014 per call.
///
/// Returns a `WeightOCRResult` with weight + unit + exercise + confidence,
/// plus alternatives so the UI can ask "Bench or Incline?" when unsure.
nonisolated final class WeightOCRService: Sendable {
    static let shared = WeightOCRService()
    private init() {}

    nonisolated struct Result: Sendable {
        let weight: Double?
        let unit: String                // "lbs" | "kg"
        let exercise: String?
        let exerciseAlternatives: [String]
        let exerciseConfidence: Double  // 0...1
        let weightConfidence: Double    // 0...1
        let plateBreakdown: PlateBreakdown?
        let detectedKind: Kind
        let rawNumbers: [Double]        // all numeric tokens we saw
        let source: Source

        enum Source: String, Sendable { case appleVision, gemini, hybrid }
        enum Kind: String, Sendable {
            case selectorPin       // weight-stack pin selector
            case sticker           // dumbbell head, plate sticker
            case ledDisplay        // treadmill/digital scale
            case loadedBarbell     // bar with plates
            case dial              // engraved dial
            case unclear
        }

        struct PlateBreakdown: Sendable {
            let perSidePlates: [(weight: Double, count: Int)]
            let barWeight: Double
            var total: Double {
                let plateSum = perSidePlates.reduce(0.0) { $0 + Double($1.count) * $1.weight }
                return plateSum * 2 + barWeight
            }
        }
    }

    /// Two-stage analysis. Always returns a Result (with low confidence
    /// rather than throwing) so the UI can show "we got these numbers,
    /// pick one" even on degraded photos.
    @MainActor
    func analyze(image: UIImage, profile: UserProfile) async -> Result {
        // Stage 1 — Apple Vision OCR. Fast, free, decent for printed text.
        let ocrNumbers = await runAppleOCR(image: image)

        // Stage 2 — Gemini scene-understanding. Always run for now; later
        // we could short-circuit when OCR returns a single clean weight
        // value (sticker / selector case).
        let gemini = await runGemini(image: image, ocrHints: ocrNumbers, profile: profile)

        // Prefer Gemini's structured output when available; otherwise fall
        // back to OCR-only (no exercise context).
        if let g = gemini {
            return Result(
                weight: g.totalWeight,
                unit: g.unit,
                exercise: g.exercise,
                exerciseAlternatives: g.exerciseAlternatives,
                exerciseConfidence: g.exerciseConfidence,
                weightConfidence: g.weightConfidence,
                plateBreakdown: g.plateBreakdown,
                detectedKind: g.kind,
                rawNumbers: ocrNumbers,
                source: ocrNumbers.isEmpty ? .gemini : .hybrid
            )
        }
        // Pure-OCR path: pick the largest sensible number as the weight.
        let weight = pickWeight(from: ocrNumbers)
        return Result(
            weight: weight,
            unit: profile.usesMetric ? "kg" : "lbs",
            exercise: nil,
            exerciseAlternatives: [],
            exerciseConfidence: 0,
            weightConfidence: weight == nil ? 0 : 0.5,
            plateBreakdown: nil,
            detectedKind: .unclear,
            rawNumbers: ocrNumbers,
            source: .appleVision
        )
    }

    // MARK: - Apple Vision (stage 1)

    private func runAppleOCR(image: UIImage) async -> [Double] {
        guard let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { req, _ in
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let candidates = observations.flatMap { obs -> [String] in
                    obs.topCandidates(3).map(\.string)
                }
                let numbers = candidates.flatMap { Self.extractNumbers(from: $0) }
                cont.resume(returning: numbers)
            }
            // .fast prevents Apple's language-correction from "fixing" 0→©.
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            request.customWords = ["lb", "lbs", "kg", "lbs.", "LB", "KG"]
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }

    /// Pull plausible weight values out of OCR text. "45", "2.5", "30 LBS",
    /// "70" — anything that looks like a gym number.
    private static func extractNumbers(from text: String) -> [Double] {
        let regex = try? NSRegularExpression(pattern: #"\d+\.?\d*"#)
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex?.matches(in: text, options: [], range: range) ?? []
        return matches.compactMap {
            Double(nsText.substring(with: $0.range))
        }
    }

    /// Heuristic: pick the largest number in the 1–500 range. Weight stack
    /// pins go up to ~200 lb / 95 kg; loaded bars ~500 lb. Numbers outside
    /// that are usually noise (dates, model numbers, etc.).
    private func pickWeight(from numbers: [Double]) -> Double? {
        let plausible = numbers.filter { $0 >= 2 && $0 <= 500 }
        return plausible.max()
    }

    // MARK: - Gemini (stage 2)

    private struct GeminiSceneAnalysis: Sendable {
        let totalWeight: Double?
        let unit: String
        let exercise: String?
        let exerciseAlternatives: [String]
        let exerciseConfidence: Double
        let weightConfidence: Double
        let plateBreakdown: Result.PlateBreakdown?
        let kind: Result.Kind
    }

    @MainActor
    private func runGemini(image: UIImage, ocrHints: [Double], profile: UserProfile) async -> GeminiSceneAnalysis? {
        guard let jpeg = image.jpegData(compressionQuality: 0.8) else { return nil }
        let base64 = jpeg.base64EncodedString()
        let unitPref = profile.usesMetric ? "kg" : "lbs"

        let system = """
        You analyze gym-equipment photos and extract structured data. Return
        a strict JSON object with these fields:

          - kind: one of "selectorPin" | "sticker" | "ledDisplay" |
            "loadedBarbell" | "dial" | "unclear"
          - exercise: best-guess exercise name (e.g. "Bench Press",
            "Lat Pulldown", "Squat (Barbell)"). null if unclear.
          - exerciseAlternatives: array of 0-3 plausible alternatives if
            you're not certain (e.g. could be Bench OR Incline Bench).
          - exerciseConfidence: number 0..1
          - unit: "\(unitPref)" preferred unless equipment text says otherwise.
          - weight: total weight as a number (combined plates + bar for
            loadedBarbell, displayed value for selectorPin/sticker/ledDisplay).
            null if unable.
          - weightConfidence: number 0..1
          - plateBreakdown: object with perSidePlates (array of {weight, count})
            and barWeight. Only fill for loadedBarbell. null otherwise.
          - reasoning: one short sentence on how you arrived at the weight.

        Default barbell weight: \(profile.usesMetric ? "20" : "45") \(unitPref).
        OCR text hints (numbers found): \(ocrHints.map { "\($0)" }.joined(separator: ", "))

        No prose. JSON only.
        """

        let schema: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "kind": ["type": "string"],
                "exercise": ["type": "string"],
                "exerciseAlternatives": ["type": "array", "items": ["type": "string"]],
                "exerciseConfidence": ["type": "number"],
                "unit": ["type": "string"],
                "weight": ["type": "number"],
                "weightConfidence": ["type": "number"],
                "plateBreakdown": [
                    "type": "object",
                    "properties": [
                        "perSidePlates": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "weight": ["type": "number"],
                                    "count": ["type": "integer"]
                                ]
                            ]
                        ],
                        "barWeight": ["type": "number"]
                    ]
                ],
                "reasoning": ["type": "string"]
            ]),
            "required": AnyCodable(["kind"])
        ]

        let ai = AIService()
        let raw: String
        do {
            raw = try await ai.analyzeImageWithSchemaJSON(
                imageBase64: base64,
                systemPrompt: system,
                userPrompt: "Identify the exercise and extract the weight.",
                schema: schema
            )
        } catch {
            return nil
        }
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return Self.parseGeminiDict(dict, defaultUnit: unitPref)
    }

    private static func parseGeminiDict(_ dict: [String: Any], defaultUnit: String) -> GeminiSceneAnalysis {
        let kind: Result.Kind = {
            switch (dict["kind"] as? String)?.lowercased() {
            case "selectorpin": return .selectorPin
            case "sticker": return .sticker
            case "leddisplay": return .ledDisplay
            case "loadedbarbell": return .loadedBarbell
            case "dial": return .dial
            default: return .unclear
            }
        }()
        let plateBreakdown: Result.PlateBreakdown? = {
            guard let pb = dict["plateBreakdown"] as? [String: Any],
                  let plates = pb["perSidePlates"] as? [[String: Any]] else { return nil }
            let parsed = plates.compactMap { p -> (Double, Int)? in
                guard let w = p["weight"] as? Double, let c = p["count"] as? Int else { return nil }
                return (w, c)
            }
            let bar = pb["barWeight"] as? Double ?? 45
            return Result.PlateBreakdown(perSidePlates: parsed, barWeight: bar)
        }()
        return GeminiSceneAnalysis(
            totalWeight: dict["weight"] as? Double,
            unit: (dict["unit"] as? String) ?? defaultUnit,
            exercise: (dict["exercise"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            exerciseAlternatives: (dict["exerciseAlternatives"] as? [String]) ?? [],
            exerciseConfidence: dict["exerciseConfidence"] as? Double ?? 0,
            weightConfidence: dict["weightConfidence"] as? Double ?? 0,
            plateBreakdown: plateBreakdown,
            kind: kind
        )
    }
}
