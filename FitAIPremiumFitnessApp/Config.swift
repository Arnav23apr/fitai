import Foundation

enum Config {
    static let SUPABASE_URL: String = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
    static let SUPABASE_ANON_KEY: String = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    static let EXPO_PUBLIC_TOOLKIT_URL: String = Bundle.main.object(forInfoDictionaryKey: "EXPO_PUBLIC_TOOLKIT_URL") as? String ?? ""
    static let EXPO_PUBLIC_REVENUECAT_IOS_API_KEY: String = Bundle.main.object(forInfoDictionaryKey: "EXPO_PUBLIC_REVENUECAT_IOS_API_KEY") as? String ?? ""
    static let EXPO_PUBLIC_REVENUECAT_TEST_API_KEY: String = Bundle.main.object(forInfoDictionaryKey: "EXPO_PUBLIC_REVENUECAT_TEST_API_KEY") as? String ?? ""
}
