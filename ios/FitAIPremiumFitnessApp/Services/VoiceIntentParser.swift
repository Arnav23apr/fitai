import Foundation

/// Discriminated-union output of a voice utterance. ActiveSessionView's
/// dispatcher matches on this and mutates session state accordingly.
nonisolated enum VoiceIntent: Sendable {
    case logSet(LogSet)
    case tagSet(TagSet)
    case structure(Structure)
    case rest(Rest)
    case query(Query)
    case session(Session)
    case unit(Bool)                 // true = metric (kilos), false = imperial
    case unrecognized(transcript: String)

    nonisolated struct LogSet: Sendable {
        let weight: Double?
        let reps: Int
        let position: Position?     // first / second / specific # / next-empty
        let tag: SetType?           // tagged at log time, e.g. "log warmup at 135 for 8"
    }

    nonisolated enum Position: Sendable {
        case first, second, third, fourth, fifth, sixth
        case specific(Int)
        case nextEmpty
    }

    nonisolated struct TagSet: Sendable {
        let position: Position
        let tag: SetType
    }

    nonisolated enum Structure: Sendable {
        case addSet(tag: SetType?)
        case removeLastSet
        case addExercise(name: String)
        case replaceExercise(from: String, to: String)
        case skipExercise
        case nextExercise
    }

    nonisolated enum Rest: Sendable {
        case start(seconds: Int)
        case adjust(delta: Int)
        case skip
    }

    nonisolated enum Query: Sendable {
        case lastSession           // "what did I do last time"
        case personalRecord        // "what's my PR"
        case elapsedTime           // "how long have I been here"
        case nextExercise          // "what's next"
        case restRemaining         // "how much rest left"
    }

    nonisolated enum Session: Sendable {
        case finish
        case cancel
        case saveAsTemplate
    }
}

/// Parses a transcribed user utterance into a `VoiceIntent`.
///
/// Pipeline (cheapest → most expensive):
/// 1. Regex over normalized text — covers ~80% of utterances instantly.
/// 2. Apple Foundation Models (iOS 26+) with `@Generable` guided generation
///    — free, on-device, perfect for the long tail. (Skipped here — we
///    fall through to Gemini until we drop iOS 25 support.)
/// 3. Gemini Flash Lite structured-JSON — final fallback for anything the
///    regex misses. Costs ~$0.000025 per call.
nonisolated struct VoiceIntentParser: Sendable {

    static let shared = VoiceIntentParser()

    private init() {}

    /// Public entry. Returns an intent or `unrecognized` (which surfaces
    /// in the UI as "I didn't catch that — try again").
    @MainActor
    func parse(transcript raw: String) async -> VoiceIntent {
        let text = normalize(raw)
        guard !text.isEmpty else { return .unrecognized(transcript: raw) }

        if let local = parseLocally(text) { return local }
        if let ai = await parseRemote(text) { return ai }
        return .unrecognized(transcript: raw)
    }

    // MARK: - Local parsing (regex-first, no API call)

    /// Tries every fast-path matcher in order. Returns the first hit.
    private func parseLocally(_ t: String) -> VoiceIntent? {
        // Order matters — more specific patterns first so "log warmup at
        // 135 for 8" doesn't get caught by the bare-numbers pattern.
        if let v = matchLogSetWithPosition(t) { return v }
        if let v = matchLogSetTagged(t) { return v }
        if let v = matchLogSetBare(t) { return v }
        if let v = matchTag(t) { return v }
        if let v = matchStructure(t) { return v }
        if let v = matchRest(t) { return v }
        if let v = matchQuery(t) { return v }
        if let v = matchSession(t) { return v }
        if let v = matchUnit(t) { return v }
        return nil
    }

    /// "log [first/second/...] set [as] 245 for 3"
    /// "log set [number] [as] 245 for 3"
    private func matchLogSetWithPosition(_ t: String) -> VoiceIntent? {
        let patterns = [
            #"log\s+(first|second|third|fourth|fifth|sixth)\s+set\s+(?:as\s+)?(\d+\.?\d*)\s*(?:lb|lbs|pound|pounds|kg|kilo|kilos)?\s*(?:for|x|by|times)\s*(\d+)"#,
            #"log\s+set\s+(\d+)\s+(?:as\s+)?(\d+\.?\d*)\s*(?:lb|lbs|pound|pounds|kg|kilo|kilos)?\s*(?:for|x|by|times)\s*(\d+)"#
        ]
        for pattern in patterns {
            guard let match = firstMatch(t, pattern: pattern) else { continue }
            // Pattern 1: position word; Pattern 2: numeric set#
            if let posWord = match[safe: 1], let pos = positionFromWord(posWord),
               let weight = match[safe: 2].flatMap(Double.init),
               let reps = match[safe: 3].flatMap(Int.init) {
                return .logSet(.init(weight: weight, reps: reps, position: pos, tag: nil))
            }
            if let setNum = match[safe: 1].flatMap(Int.init),
               let weight = match[safe: 2].flatMap(Double.init),
               let reps = match[safe: 3].flatMap(Int.init) {
                return .logSet(.init(weight: weight, reps: reps, position: .specific(setNum), tag: nil))
            }
        }
        return nil
    }

    /// "log warmup at 135 for 8", "log this set as a drop set 200 for 5"
    private func matchLogSetTagged(_ t: String) -> VoiceIntent? {
        let pattern = #"log\s+(?:a\s+)?(warmup|warm-up|warm up|drop set|drop-set|failure|failure set)\s+(?:set\s+)?(?:at\s+|of\s+|as\s+)?(\d+\.?\d*)\s*(?:lb|lbs|pound|pounds|kg|kilo|kilos)?\s*(?:for|x|by|times)\s*(\d+)"#
        guard let match = firstMatch(t, pattern: pattern),
              let tagWord = match[safe: 1],
              let weight = match[safe: 2].flatMap(Double.init),
              let reps = match[safe: 3].flatMap(Int.init) else { return nil }
        let tag = setTypeFromWord(tagWord) ?? .normal
        return .logSet(.init(weight: weight, reps: reps, position: .nextEmpty, tag: tag))
    }

    /// Bare numbers — "245 for 3", "log this set", "8 reps at 135"
    private func matchLogSetBare(_ t: String) -> VoiceIntent? {
        // "log this set" — apply current row values
        if t.range(of: #"^(?:log|save)(?:\s+this(?:\s+set)?)?$"#, options: .regularExpression) != nil {
            return .logSet(.init(weight: nil, reps: 0, position: .nextEmpty, tag: nil))
        }
        // "245 for 3", "245 by 3", "245 x 3"
        if let match = firstMatch(t, pattern: #"^(\d+\.?\d*)\s*(?:lb|lbs|pound|pounds|kg|kilo|kilos)?\s*(?:for|x|by|times)\s*(\d+)$"#),
           let weight = match[safe: 1].flatMap(Double.init),
           let reps = match[safe: 2].flatMap(Int.init) {
            return .logSet(.init(weight: weight, reps: reps, position: .nextEmpty, tag: nil))
        }
        // "8 reps at 135", "10 at 60 kilos"
        if let match = firstMatch(t, pattern: #"^(\d+)\s*reps?\s*(?:at|@|with)\s+(\d+\.?\d*)\s*(?:lb|lbs|pound|pounds|kg|kilo|kilos)?$"#),
           let reps = match[safe: 1].flatMap(Int.init),
           let weight = match[safe: 2].flatMap(Double.init) {
            return .logSet(.init(weight: weight, reps: reps, position: .nextEmpty, tag: nil))
        }
        // "log [number]" — just reps, weight from history
        if let match = firstMatch(t, pattern: #"^(?:log\s+)?(\d+)\s*reps?$"#),
           let reps = match[safe: 1].flatMap(Int.init) {
            return .logSet(.init(weight: nil, reps: reps, position: .nextEmpty, tag: nil))
        }
        return nil
    }

    /// "mark this as a warmup", "make set 3 a drop set"
    private func matchTag(_ t: String) -> VoiceIntent? {
        let pattern = #"(?:mark|make)\s+(?:this|that|set\s+(\d+)|the\s+last\s+set)\s+(?:as\s+)?(?:a\s+)?(warmup|warm-up|warm up|drop set|drop-set|failure|failure set)"#
        guard let match = firstMatch(t, pattern: pattern) else { return nil }
        let tag = setTypeFromWord(match[safe: 2] ?? "") ?? .normal
        let pos: VoiceIntent.Position = {
            if let n = match[safe: 1].flatMap(Int.init) { return .specific(n) }
            return .nextEmpty   // covers "this", "that", "last set" — handled in dispatcher
        }()
        return .tagSet(.init(position: pos, tag: tag))
    }

    /// Add / remove / replace / skip / next
    private func matchStructure(_ t: String) -> VoiceIntent? {
        if t.range(of: #"add\s+(?:a\s+|another\s+)?warmup\s+set"#, options: .regularExpression) != nil {
            return .structure(.addSet(tag: .warmup))
        }
        if t.range(of: #"add\s+(?:a\s+|another\s+)?(?:drop\s+)?set"#, options: .regularExpression) != nil {
            return .structure(.addSet(tag: nil))
        }
        if t.range(of: #"(?:remove|delete|undo)\s+(?:the\s+)?last\s+set"#, options: .regularExpression) != nil {
            return .structure(.removeLastSet)
        }
        if let match = firstMatch(t, pattern: #"replace\s+(.+?)\s+with\s+(.+?)$"#),
           let from = match[safe: 1], let to = match[safe: 2] {
            return .structure(.replaceExercise(from: from.trimmed, to: to.trimmed))
        }
        if let match = firstMatch(t, pattern: #"^(?:add|insert)\s+(.+?)$"#),
           let exercise = match[safe: 1], !exercise.isEmpty {
            // Avoid clashing with "add a set" already handled above.
            if exercise.contains("set") { return nil }
            return .structure(.addExercise(name: exercise.trimmed))
        }
        if t.range(of: #"^(?:skip(?:\s+this(?:\s+exercise)?)?|next\s+exercise|move\s+on)$"#, options: .regularExpression) != nil {
            return .structure(.skipExercise)
        }
        return nil
    }

    /// "start a 90 second rest", "add 30 seconds", "skip rest"
    private func matchRest(_ t: String) -> VoiceIntent? {
        if t.range(of: #"^skip\s+rest$"#, options: .regularExpression) != nil {
            return .rest(.skip)
        }
        if let match = firstMatch(t, pattern: #"^add\s+(\d+)\s*(?:second|seconds|sec)?$"#),
           let s = match[safe: 1].flatMap(Int.init) {
            return .rest(.adjust(delta: s))
        }
        if let match = firstMatch(t, pattern: #"^(?:start\s+(?:a\s+)?(?:rest\s+(?:of\s+)?)?)?(\d+)\s*(?:second|seconds|sec)?\s+rest$"#),
           let s = match[safe: 1].flatMap(Int.init) {
            return .rest(.start(seconds: s))
        }
        if let match = firstMatch(t, pattern: #"^start\s+(?:a\s+)?(\d+)\s*(?:second|seconds|sec)?\s+rest$"#),
           let s = match[safe: 1].flatMap(Int.init) {
            return .rest(.start(seconds: s))
        }
        return nil
    }

    /// Read-back queries
    private func matchQuery(_ t: String) -> VoiceIntent? {
        if t.range(of: #"what(?:'s| is| did) (?:i|my)? ?(?:do|did)? ?last\s+time"#, options: .regularExpression) != nil {
            return .query(.lastSession)
        }
        if t.range(of: #"(?:what(?:'s| is)|tell me)\s+my\s+(?:pr|personal\s+record)"#, options: .regularExpression) != nil {
            return .query(.personalRecord)
        }
        if t.range(of: #"how\s+long\s+(?:have\s+i|am\s+i|have\s+we)"#, options: .regularExpression) != nil {
            return .query(.elapsedTime)
        }
        if t.range(of: #"(?:what(?:'s| is)\s+)?next(?:\s+exercise)?$"#, options: .regularExpression) != nil {
            return .query(.nextExercise)
        }
        if t.range(of: #"how\s+much\s+rest"#, options: .regularExpression) != nil {
            return .query(.restRemaining)
        }
        return nil
    }

    /// Session-level commands
    private func matchSession(_ t: String) -> VoiceIntent? {
        if t.range(of: #"^(?:save\s+(?:and\s+)?finish|finish\s+workout|end\s+workout|i'm\s+done)$"#, options: .regularExpression) != nil {
            return .session(.finish)
        }
        if t.range(of: #"^cancel(?:\s+workout)?$"#, options: .regularExpression) != nil {
            return .session(.cancel)
        }
        if t.range(of: #"^save(?:\s+as)?\s+template$"#, options: .regularExpression) != nil {
            return .session(.saveAsTemplate)
        }
        return nil
    }

    /// Unit toggles
    private func matchUnit(_ t: String) -> VoiceIntent? {
        if t.range(of: #"(?:switch\s+to|use)\s+(?:kilo|kilos|kg|metric)"#, options: .regularExpression) != nil {
            return .unit(true)
        }
        if t.range(of: #"(?:switch\s+to|use)\s+(?:pound|pounds|lb|lbs|imperial)"#, options: .regularExpression) != nil {
            return .unit(false)
        }
        return nil
    }

    // MARK: - Remote fallback (Gemini)

    /// AI fallback for anything regex didn't catch. Returns nil if the AI
    /// call fails; caller surfaces unrecognized.
    @MainActor
    private func parseRemote(_ text: String) async -> VoiceIntent? {
        let schema: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "intent": ["type": "string"],
                "weight": ["type": "number"],
                "reps": ["type": "integer"],
                "position": ["type": "string"],
                "setNumber": ["type": "integer"],
                "tag": ["type": "string"],
                "exerciseName": ["type": "string"],
                "fromExercise": ["type": "string"],
                "toExercise": ["type": "string"],
                "seconds": ["type": "integer"],
                "metric": ["type": "boolean"]
            ]),
            "required": AnyCodable(["intent"])
        ]
        let system = """
        You are a strict voice-command parser for a fitness app. Output ONE
        JSON object representing a single user intent. The "intent" field is
        one of:

          - "logSet"       (fields: weight, reps, position, tag)
          - "tagSet"       (fields: position OR setNumber, tag)
          - "addSet"       (fields: tag — optional)
          - "removeLastSet"
          - "addExercise"  (fields: exerciseName)
          - "replaceExercise" (fields: fromExercise, toExercise)
          - "skipExercise"
          - "startRest"    (fields: seconds)
          - "adjustRest"   (fields: seconds)   — positive = add, negative = subtract
          - "skipRest"
          - "queryLast" | "queryPR" | "queryElapsed" | "queryNext" | "queryRestLeft"
          - "finish" | "cancel" | "saveTemplate"
          - "setUnit"      (fields: metric — true=kg, false=lbs)
          - "unrecognized"

        position one of: "first","second","third","fourth","fifth","sixth","nextEmpty".
        tag one of: "warmup","dropSet","failure","normal".

        Respond with only the JSON.
        """
        let userMsg = "Transcript: \"\(text)\""

        let ai = AIService()
        guard let raw = try? await ai.chatJSON(systemPrompt: system, userPrompt: userMsg, schema: schema),
              let data = raw.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return VoiceIntent.fromDict(dict)
    }

    // MARK: - Helpers

    /// Lowercase, strip punctuation, collapse whitespace.
    private func normalize(_ raw: String) -> String {
        let lower = raw.lowercased()
        let stripped = lower.replacingOccurrences(of: #"[\.\,\?\!]"#, with: "", options: .regularExpression)
        return stripped.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmed
    }

    /// Captured groups as plain strings — missing/optional groups become
    /// empty strings to avoid double-Optional unwrapping at every call
    /// site. Group 0 is the full match.
    private func firstMatch(_ text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        var groups: [String] = []
        for i in 0..<match.numberOfRanges {
            let r = match.range(at: i)
            if r.location == NSNotFound {
                groups.append("")
            } else if let swiftRange = Range(r, in: text) {
                groups.append(String(text[swiftRange]))
            } else {
                groups.append("")
            }
        }
        return groups
    }

    private func positionFromWord(_ word: String) -> VoiceIntent.Position? {
        switch word.lowercased() {
        case "first": return .first
        case "second": return .second
        case "third": return .third
        case "fourth": return .fourth
        case "fifth": return .fifth
        case "sixth": return .sixth
        default: return nil
        }
    }

    private func setTypeFromWord(_ word: String) -> SetType? {
        let w = word.lowercased().replacingOccurrences(of: "-", with: " ")
        if w.contains("warm") { return .warmup }
        if w.contains("drop") { return .dropSet }
        if w.contains("fail") { return .failure }
        return nil
    }
}

// MARK: - Dict → VoiceIntent (remote AI path)

extension VoiceIntent {
    static func fromDict(_ dict: [String: Any]) -> VoiceIntent? {
        guard let intent = dict["intent"] as? String else { return nil }
        let weight = dict["weight"] as? Double
        let reps = dict["reps"] as? Int ?? 0
        let position = positionFromString(dict["position"] as? String, setNumber: dict["setNumber"] as? Int)
        let tag = setTypeFromString(dict["tag"] as? String)
        let seconds = dict["seconds"] as? Int ?? 0

        switch intent {
        case "logSet":
            return .logSet(.init(weight: weight, reps: reps, position: position, tag: tag))
        case "tagSet":
            guard let position else { return nil }
            return .tagSet(.init(position: position, tag: tag ?? .normal))
        case "addSet":
            return .structure(.addSet(tag: tag))
        case "removeLastSet":
            return .structure(.removeLastSet)
        case "addExercise":
            guard let name = dict["exerciseName"] as? String, !name.isEmpty else { return nil }
            return .structure(.addExercise(name: name))
        case "replaceExercise":
            guard let from = dict["fromExercise"] as? String,
                  let to = dict["toExercise"] as? String else { return nil }
            return .structure(.replaceExercise(from: from, to: to))
        case "skipExercise":
            return .structure(.skipExercise)
        case "startRest":
            return .rest(.start(seconds: seconds))
        case "adjustRest":
            return .rest(.adjust(delta: seconds))
        case "skipRest":
            return .rest(.skip)
        case "queryLast": return .query(.lastSession)
        case "queryPR": return .query(.personalRecord)
        case "queryElapsed": return .query(.elapsedTime)
        case "queryNext": return .query(.nextExercise)
        case "queryRestLeft": return .query(.restRemaining)
        case "finish": return .session(.finish)
        case "cancel": return .session(.cancel)
        case "saveTemplate": return .session(.saveAsTemplate)
        case "setUnit":
            return .unit(dict["metric"] as? Bool ?? false)
        default:
            return nil
        }
    }

    private static func positionFromString(_ s: String?, setNumber: Int?) -> VoiceIntent.Position? {
        if let n = setNumber, n > 0 { return .specific(n) }
        switch s?.lowercased() {
        case "first": return .first
        case "second": return .second
        case "third": return .third
        case "fourth": return .fourth
        case "fifth": return .fifth
        case "sixth": return .sixth
        case "nextempty", "next", nil: return .nextEmpty
        default: return .nextEmpty
        }
    }

    private static func setTypeFromString(_ s: String?) -> SetType? {
        switch s?.lowercased() {
        case "warmup", "warm-up", "warm up": return .warmup
        case "dropset", "drop-set", "drop set": return .dropSet
        case "failure": return .failure
        case "normal", nil, "": return .normal
        default: return nil
        }
    }
}

private extension String {
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
