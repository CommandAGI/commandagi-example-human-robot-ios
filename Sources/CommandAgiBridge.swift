import Foundation

/// Registers THIS phone as a robot on CommandAGI and bridges it: streams the camera up (cam-head)
/// and surfaces the control actions the platform sends down. Producer side of the robot API — the
/// phone *is* the robot. Mirrors the Android CommandAgiBridge wire protocol exactly.
final class CommandAgiBridge: NSObject, URLSessionWebSocketTaskDelegate {
    private let apiKey: String
    private let baseURL: String
    private let onAction: (String, [String: Any]) -> Void
    private let onStatus: (String) -> Void

    private var task: URLSessionWebSocketTask?
    private lazy var urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private(set) var connected = false

    init(apiKey: String, baseURL: String,
         onAction: @escaping (String, [String: Any]) -> Void,
         onStatus: @escaping (String) -> Void) {
        self.apiKey = apiKey
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.onAction = onAction
        self.onStatus = onStatus
    }

    // MARK: - lifecycle
    func start() {
        onStatus("Registering robot…")
        Task {
            do {
                let session = try await post("/machines", ["title": "phone-robot"])
                guard let sessionId = session["sessionId"] as? String else { throw Err.bad("no sessionId") }
                let dev = try await post("/sessions/\(sessionId)/connect-device", ["kind": "robot", "name": "iPhone"])
                guard let controlUrl = dev["controlUrl"] as? String,
                      let token = dev["token"] as? String else { throw Err.bad("no controlUrl/token") }
                openSocket(controlUrl: controlUrl, token: token)
            } catch {
                onStatus("Error: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        connected = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    /// Publish one camera frame (JPEG) on the cam-head channel.
    func sendFrame(_ jpeg: Data) {
        guard connected, let task = task else { return }
        let url = "data:image/jpeg;base64," + jpeg.base64EncodedString()
        let msg = json(["type": "frame", "channelId": "cam-head", "url": url])
        task.send(.string(msg)) { _ in }
    }

    // MARK: - socket
    private func openSocket(controlUrl: String, token: String) {
        var wsUrl = controlUrl
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        wsUrl += (wsUrl.contains("?") ? "&" : "?") + "runtime=1&role=agent&token=\(token)"
        guard let url = URL(string: wsUrl) else { onStatus("Bad control URL"); return }
        let t = urlSession.webSocketTask(with: url)
        task = t
        t.resume()
        // Announce we're live + our one camera channel.
        t.send(.string(json(["type": "status", "status": "live"]))) { _ in }
        t.send(.string(json([
            "type": "channels",
            "channels": [["channelId": "cam-head", "label": "Camera", "kind": "camera"]],
        ]))) { _ in }
        connected = true
        onStatus("Live — you're a robot")
        receive()
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let e):
                self.connected = false
                self.onStatus("Disconnected: \(e.localizedDescription)")
            case .success(let message):
                if case .string(let text) = message { self.handle(text) }
                self.receive()
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if obj["type"] as? String == "control" {
            let action = obj["action"] as? String ?? ""
            let payload = obj["payload"] as? [String: Any] ?? [:]
            onAction(action, payload)
        }
    }

    // MARK: - REST
    private func post(_ path: String, _ body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Err.bad("POST \(path) failed")
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func json(_ obj: [String: Any]) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: obj) else { return "{}" }
        return String(data: d, encoding: .utf8) ?? "{}"
    }

    enum Err: Error, LocalizedError {
        case bad(String)
        var errorDescription: String? { if case .bad(let m) = self { return m }; return nil }
    }
}
