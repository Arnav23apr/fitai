import Foundation
import Testing
@testable import FitAI

struct ProfileAndRankTests {

    @Test("UserProfile free scan gates first scan, premium, and referral scans")
    func scanEntitlementGates() {
        var profile = UserProfile()
        #expect(profile.canScanFree)

        profile.totalScans = 1
        #expect(!profile.canScanFree)

        profile.freeScansEarned = 1
        #expect(profile.canScanFree)

        profile.freeScansEarned = 0
        profile.isPremium = true
        #expect(profile.canScanFree)
    }

    @Test("UserProfile AI coach quota is lifetime-gated for free users")
    func aiCoachQuotaGate() {
        var profile = UserProfile()
        profile.aiChatMessagesUsed = UserProfile.freeAIChatQuota - 1
        #expect(profile.canSendAICoachMessage)

        profile.aiChatMessagesUsed = UserProfile.freeAIChatQuota
        #expect(!profile.canSendAICoachMessage)

        profile.isPremium = true
        #expect(profile.canSendAICoachMessage)
    }

    @Test("UserProfile premium gates challenges and goal projection")
    func premiumOnlyGates() {
        var profile = UserProfile()
        #expect(!profile.canCreateChallenge)
        #expect(!profile.canSeeGoalProjection)

        profile.isPremium = true
        #expect(profile.canCreateChallenge)
        #expect(profile.canSeeGoalProjection)
    }

    @Test("UserProfile photo consent tracks current policy version")
    func photoConsentGate() {
        var profile = UserProfile()
        #expect(!profile.hasGrantedPhotoConsent)

        profile.photoConsentVersion = UserProfile.currentPhotoConsentVersion
        profile.photoConsentGrantedAt = Date()
        #expect(profile.hasGrantedPhotoConsent)
    }

    @Test("UserProfile codable excludes custom photo data")
    func codableExcludesCustomPhotoData() throws {
        var profile = UserProfile()
        profile.name = "Arnav"
        profile.customPhotoData = Data([1, 2, 3])

        let data = try JSONEncoder().encode(profile)
        let restored = try JSONDecoder().decode(UserProfile.self, from: data)

        #expect(restored.name == "Arnav")
        #expect(restored.customPhotoData == nil)
    }

    @Test("PhysiqueRank maps nil and non-positive scores to unranked")
    func physiqueRankUnranked() {
        #expect(PhysiqueRank.rank(score: nil, gender: "male") == .unranked)
        #expect(PhysiqueRank.rank(score: 0, gender: "female") == .unranked)
    }

    @Test("PhysiqueRank maps male score boundaries")
    func physiqueRankMaleBoundaries() {
        #expect(PhysiqueRank.rank(score: 1.9, gender: "male") == .sub2)
        #expect(PhysiqueRank.rank(score: 2.0, gender: "male") == .sub3)
        #expect(PhysiqueRank.rank(score: 3.0, gender: "male") == .truecel)
        #expect(PhysiqueRank.rank(score: 4.0, gender: "male") == .incelTier)
        #expect(PhysiqueRank.rank(score: 5.0, gender: "male") == .normie)
        #expect(PhysiqueRank.rank(score: 6.0, gender: "male") == .htn)
        #expect(PhysiqueRank.rank(score: 7.0, gender: "male") == .chadlite)
        #expect(PhysiqueRank.rank(score: 8.0, gender: "male") == .chad)
        #expect(PhysiqueRank.rank(score: 9.0, gender: "male") == .gigaChad)
    }

    @Test("PhysiqueRank maps female score boundaries")
    func physiqueRankFemaleBoundaries() {
        #expect(PhysiqueRank.rank(score: 3.0, gender: "female") == .femcel)
        #expect(PhysiqueRank.rank(score: 4.0, gender: "woman") == .belowAvg)
        #expect(PhysiqueRank.rank(score: 5.0, gender: "f") == .becky)
        #expect(PhysiqueRank.rank(score: 6.0, gender: "female") == .htb)
        #expect(PhysiqueRank.rank(score: 7.0, gender: "female") == .stacylite)
        #expect(PhysiqueRank.rank(score: 8.0, gender: "female") == .stacy)
        #expect(PhysiqueRank.rank(score: 9.0, gender: "female") == .gigaStacy)
    }

    @Test("PhysiqueRank stored tier strings round-trip or fall back")
    func physiqueRankFromStoredTier() {
        #expect(PhysiqueRank.from(tier: "Chadlite") == .chadlite)
        #expect(PhysiqueRank.from(tier: "Unknown") == .unranked)
        #expect(PhysiqueRank.gigaChad.ordinal > PhysiqueRank.chad.ordinal)
        #expect(PhysiqueRank.unranked.ordinal < PhysiqueRank.sub2.ordinal)
    }
}
