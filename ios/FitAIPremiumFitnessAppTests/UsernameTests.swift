import Testing
@testable import FitAI

struct UsernameTests {

    @Test("UsernameValidator accepts a clean handle")
    func validatorAcceptsCleanHandle() {
        #expect(UsernameValidator.validate("arnav_lifts.99") == nil)
    }

    @Test("UsernameValidator trims and lowercases before validating")
    func validatorNormalizesBeforeValidating() {
        #expect(UsernameValidator.validate("  FitAI  ") != nil)
        if let error = UsernameValidator.validate("  FitAI  ") {
            #expect(UsernameValidator.message(for: error) == "That username is reserved.")
        }
    }

    @Test("UsernameValidator rejects length boundaries")
    func validatorRejectsLengthBoundaries() {
        if let short = UsernameValidator.validate("ab") {
            #expect(UsernameValidator.message(for: short) == "Username must be at least 3 characters.")
        } else {
            Issue.record("Expected too-short username to fail")
        }

        if let long = UsernameValidator.validate("abcdefghijklmnopqrstu") {
            #expect(UsernameValidator.message(for: long) == "Username must be 20 characters or fewer.")
        } else {
            Issue.record("Expected too-long username to fail")
        }
    }

    @Test("UsernameValidator rejects disallowed characters")
    func validatorRejectsInvalidCharacters() {
        if let error = UsernameValidator.validate("arnav-lifts") {
            #expect(UsernameValidator.message(for: error) == "Use only letters, numbers, underscores, or periods.")
        } else {
            Issue.record("Expected hyphenated username to fail")
        }
    }

    @Test("UsernameSuggester returns sanitized, valid, deduped candidates")
    func suggesterReturnsValidCandidates() {
        let suggestions = UsernameSuggester.suggestions(seed: "Arnav.Kumar+fit@example.com")

        #expect(!suggestions.isEmpty)
        #expect(suggestions.count <= 7)
        #expect(Set(suggestions).count == suggestions.count)
        #expect(suggestions.allSatisfy { UsernameSuggester.isValid($0) })
        #expect(suggestions.contains("arnav"))
    }

    @Test("UsernameSuggester falls back when seed has no useful characters")
    func suggesterFallsBackForEmptySeed() {
        let suggestions = UsernameSuggester.suggestions(seed: " !!! ")

        #expect(!suggestions.isEmpty)
        #expect(suggestions.allSatisfy { UsernameSuggester.isValid($0) })
        #expect(suggestions.contains("lifter"))
    }

    @Test("UsernameSuggester validation catches separators and reserved handles")
    func suggesterValidationErrors() {
        #expect(UsernameSuggester.validationError("_arnav") == "Can't start or end with _ or .")
        #expect(UsernameSuggester.validationError("arnav__lift") == "No consecutive _ or .")
        #expect(UsernameSuggester.validationError("admin") == "That handle is reserved.")
        #expect(UsernameSuggester.validationError("arnav") == nil)
    }
}
