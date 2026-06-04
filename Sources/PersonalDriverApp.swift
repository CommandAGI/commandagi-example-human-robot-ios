import SwiftUI

/// Be a robot, on iOS. The phone registers itself as a robot on CommandAGI: its camera fills the
/// screen and streams up as the robot's observation, and the move/turn actions the platform sends
/// are shown big at the bottom for you (the human) to perform. Human control only — the Android
/// example additionally relays to a drone via an ESP32.
@main
struct PersonalDriverApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
