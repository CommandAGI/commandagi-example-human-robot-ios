import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// "Connect to CommandAGI account" — OAuth 2.0 Authorization Code + PKCE via ASWebAuthenticationSession.
/// The issued access token is a normal CommandAGI key the app then uses as a Bearer. Same public
/// client (`personal-driver`) and redirect as the Android example.
final class OAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let clientId = "personal-driver"
    static let redirectURI = "commandagi-driver://oauth"
    static let scope = "operator"

    private var session: ASWebAuthenticationSession?

    func connect(completion: @escaping (Result<String, Error>) -> Void) {
        let verifier = Self.randomString()
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomString()

        var comps = URLComponents(string: AppConfig.webBase + "/oauth/authorize")!
        comps.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: Self.clientId),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "scope", value: Self.scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
        ]
        guard let url = comps.url else { completion(.failure(OAuthError.message("bad authorize URL"))); return }

        let s = ASWebAuthenticationSession(url: url, callbackURLScheme: "commandagi-driver") { callback, error in
            if let error = error { completion(.failure(error)); return }
            guard let callback = callback,
                  let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems else {
                completion(.failure(OAuthError.message("no callback"))); return
            }
            func q(_ n: String) -> String? { items.first { $0.name == n }?.value }
            if let err = q("error") { completion(.failure(OAuthError.message(err))); return }
            guard let code = q("code"), q("state") == state else {
                completion(.failure(OAuthError.message("state check failed"))); return
            }
            Task {
                do { completion(.success(try await Self.exchange(code: code, verifier: verifier))) }
                catch { completion(.failure(error)) }
            }
        }
        s.presentationContextProvider = self
        session = s
        s.start()
    }

    private static func exchange(code: String, verifier: String) async throws -> String {
        var req = URLRequest(url: URL(string: AppConfig.baseURL + "/oauth/token")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": clientId,
            "redirect_uri": redirectURI,
            "code_verifier": verifier,
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = obj["access_token"] as? String else {
            throw OAuthError.message("token exchange failed")
        }
        return token
    }

    // MARK: - PKCE
    private static func randomString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }
    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(digest))
    }
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }

    enum OAuthError: Error, LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let m) = self { return m }; return nil }
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } ?? windows.first }
}
