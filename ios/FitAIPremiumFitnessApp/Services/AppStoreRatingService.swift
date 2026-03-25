import Foundation

nonisolated struct AppStoreRatingResponse: Codable, Sendable {
    let resultCount: Int
    let results: [AppStoreResult]
}

nonisolated struct AppStoreResult: Codable, Sendable {
    let averageUserRating: Double?
    let userRatingCount: Int?
}

@Observable
@MainActor
class AppStoreRatingService {
    static let shared = AppStoreRatingService()

    var rating: Double = 4.8
    var ratingsCount: Int = 0
    var hasFetched: Bool = false

    func fetchRating(appId: String) async {
        guard !hasFetched else { return }
        let urlString = "https://itunes.apple.com/lookup?id=\(appId)"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(AppStoreRatingResponse.self, from: data)
            if let result = response.results.first {
                if let avg = result.averageUserRating {
                    rating = (avg * 10).rounded() / 10
                }
                if let count = result.userRatingCount {
                    ratingsCount = count
                }
            }
            hasFetched = true
        } catch {
            hasFetched = true
        }
    }

    var formattedCount: String {
        if ratingsCount >= 1_000_000 {
            return String(format: "%.1fM+", Double(ratingsCount) / 1_000_000)
        } else if ratingsCount >= 1_000 {
            return String(format: "%.0fK+", Double(ratingsCount) / 1_000)
        } else if ratingsCount > 0 {
            return "\(ratingsCount)+"
        }
        return "200K+"
    }

    var formattedRating: String {
        String(format: "%.1f", rating)
    }
}
