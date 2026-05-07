import Foundation

enum UsernameValidationError {
    case tooShort
    case tooLong
    case invalidCharacters
    case profanity
    case reserved
}

enum UsernameValidator {
    static let minLength = 3
    static let maxLength = 20

    private static let allowed: CharacterSet = {
        var set = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.")
        return set
    }()

    private static let reserved: Set<String> = [
        "admin", "administrator", "root", "support", "staff", "mod", "moderator",
        "fitai", "fit_ai", "fit.ai", "official", "team", "system", "null", "undefined",
        "help", "info", "contact", "anonymous", "user", "deleted",
    ]

    private static let blocklist: Set<String> = [
        "nigger", "nigga", "n1gger", "n1gga", "niger",
        "faggot", "fagot", "f4ggot", "fag",
        "retard", "retarded", "r3tard",
        "tranny", "trannie",
        "kike", "k1ke",
        "spic", "chink", "gook", "wetback",
        "cunt", "c0nt",
        "whore", "wh0re", "slut", "sl0t",
        "rapist", "rape", "raping",
        "pedo", "pedophile", "paedo",
        "kkk", "nazi", "hitler", "hail_hitler",
        "molester", "incest",
        "bitch", "b1tch",
        "asshole", "a55hole",
        "shit", "sh1t",
        "fuck", "f0ck", "fck",
        "dick", "d1ck", "cock", "c0ck",
        "pussy", "puss",
    ]

    static func validate(_ raw: String) -> UsernameValidationError? {
        let s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count < minLength { return .tooShort }
        if s.count > maxLength { return .tooLong }
        if s.unicodeScalars.contains(where: { !allowed.contains($0) }) { return .invalidCharacters }
        if reserved.contains(s) { return .reserved }
        for word in blocklist where s.contains(word) { return .profanity }
        return nil
    }

    static func message(for error: UsernameValidationError) -> String {
        switch error {
        case .tooShort: return "Username must be at least \(minLength) characters."
        case .tooLong: return "Username must be \(maxLength) characters or fewer."
        case .invalidCharacters: return "Use only letters, numbers, underscores, or periods."
        case .profanity: return "Please choose a different username."
        case .reserved: return "That username is reserved."
        }
    }
}
