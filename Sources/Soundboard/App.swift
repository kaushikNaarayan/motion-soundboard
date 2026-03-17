import SwiftUI

@main
struct SoundboardApp: App {
    var body: some Scene {
        WindowGroup("Motion Soundboard") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
