import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var connected = AppConfig.apiKey != nil
    @State private var dictate = AppConfig.dictate
    @State private var error: String?
    @State private var busy = false
    private let oauth = OAuthManager()

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if connected {
                        Label(AppConfig.connectedViaOAuth ? "Connected to your CommandAGI account"
                                                           : "Connected (preconfigured key)",
                              systemImage: "checkmark.circle.fill")
                        Button("Disconnect", role: .destructive) {
                            AppConfig.apiKey = nil
                            AppConfig.connectedViaOAuth = false
                            connected = false
                        }
                    } else {
                        Button {
                            busy = true
                            error = nil
                            oauth.connect { result in
                                DispatchQueue.main.async {
                                    busy = false
                                    switch result {
                                    case .success(let token):
                                        AppConfig.apiKey = token
                                        AppConfig.connectedViaOAuth = true
                                        connected = true
                                    case .failure(let e):
                                        error = e.localizedDescription
                                    }
                                }
                            }
                        } label: {
                            HStack { if busy { ProgressView() }; Text("Connect to CommandAGI") }
                        }
                        Text("Connect your CommandAGI account so an agent can drive you — no API key to copy.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    if let error { Text(error).font(.footnote).foregroundColor(.red) }
                }

                Section("Human control") {
                    Toggle("Dictate directions aloud", isOn: $dictate)
                        .onChange(of: dictate) { AppConfig.dictate = $0 }
                }

                Section {
                    Text("This phone registers as a robot on CommandAGI. Its camera streams up as the robot’s view; the move/turn directions a driver sends appear big on screen for you to perform.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
