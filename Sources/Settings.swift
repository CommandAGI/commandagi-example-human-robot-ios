import Foundation

/// Single source of truth for what the app persists, plus build-time fallbacks baked into Info.plist
/// (COMMANDAGI_API_KEY / COMMANDAGI_BASE_URL) so the app can auto-connect with zero in-app setup.
enum AppConfig {
    private static let defaults = UserDefaults.standard

    static var apiKey: String? {
        get {
            if let k = defaults.string(forKey: "api_key"), !k.isEmpty { return k }
            let baked = info("COMMANDAGI_API_KEY")
            return (baked?.isEmpty == false) ? baked : nil
        }
        set { defaults.set(newValue, forKey: "api_key") }
    }

    static var baseURL: String {
        if let b = defaults.string(forKey: "base_url"), !b.isEmpty { return b }
        return info("COMMANDAGI_BASE_URL") ?? "https://api.commandagi.com"
    }

    /// Speak each instruction aloud (text-to-speech).
    static var dictate: Bool {
        get { defaults.object(forKey: "dictate") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "dictate") }
    }

    static var connectedViaOAuth: Bool {
        get { defaults.bool(forKey: "connected_oauth") }
        set { defaults.set(newValue, forKey: "connected_oauth") }
    }

    /// The web origin (consent screen) derived from the API base.
    static var webBase: String {
        baseURL
            .replacingOccurrences(of: "https://api-dev.", with: "https://dev.")
            .replacingOccurrences(of: "https://api.", with: "https://")
    }

    private static func info(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
