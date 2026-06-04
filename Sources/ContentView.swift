import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraController()
    @State private var instruction = "Connect in Settings"
    @State private var status = "Not connected"
    @State private var showSettings = false
    @State private var dictate = AppConfig.dictate

    @State private var bridge: CommandAgiBridge?
    private let speaker = AVSpeechSynthesizer()

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    Text(status)
                        .font(.system(size: 13)).foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                    Spacer()
                    Button { showSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                            .font(.system(size: 13)).foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                    }
                }
                HStack {
                    Button {
                        dictate.toggle()
                        AppConfig.dictate = dictate
                    } label: {
                        Text("Dictate: \(dictate ? "on" : "off")")
                            .font(.system(size: 13)).foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(.top, 4)

                Spacer()

                Text(instruction)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(Color.black.opacity(0.7))
            }
            .padding(16)
            .padding(.bottom, 0)
        }
        .onAppear {
            camera.onFrame = { [weak bridge] jpeg in bridge?.sendFrame(jpeg) }
            camera.start()
            connect()
        }
        .onDisappear { bridge?.stop(); camera.stop() }
        .sheet(isPresented: $showSettings, onDismiss: { connect() }) {
            SettingsView()
        }
    }

    private func connect() {
        guard let key = AppConfig.apiKey, !key.isEmpty else {
            instruction = "Connect to CommandAGI in Settings"
            return
        }
        bridge?.stop()
        let b = CommandAgiBridge(
            apiKey: key,
            baseURL: AppConfig.baseURL,
            onAction: { action, payload in
                DispatchQueue.main.async { show(action, payload) }
            },
            onStatus: { s in DispatchQueue.main.async { status = s } },
        )
        bridge = b
        camera.onFrame = { [weak b] jpeg in b?.sendFrame(jpeg) }
        b.start()
    }

    private func show(_ action: String, _ payload: [String: Any]) {
        instruction = humanText(action, payload)
        if dictate {
            speaker.speak(AVSpeechUtterance(string: spoken(action, payload)))
        }
    }

    private func humanText(_ action: String, _ payload: [String: Any]) -> String {
        switch action {
        case "move": return "⬆  MOVE FORWARD"
        case "back": return "⬇  MOVE BACKWARD"
        case "turn": return (payload["dir"] as? String == "right") ? "➡  TURN RIGHT" : "⬅  TURN LEFT"
        case "stop": return "✋  STOP"
        case "reset": return "↺  RETURN TO START"
        default: return action.uppercased()
        }
    }
    private func spoken(_ action: String, _ payload: [String: Any]) -> String {
        switch action {
        case "move": return "Move forward"
        case "back": return "Move backward"
        case "turn": return (payload["dir"] as? String == "right") ? "Turn right" : "Turn left"
        case "stop": return "Stop"
        case "reset": return "Return to start"
        default: return action
        }
    }
}
