import AppKit
import Foundation

// ── Sound option ──────────────────────────────────────────────

enum Sound: Equatable, Hashable, Identifiable {
    case system(String)     // built-in macOS sound
    case say(String)        // text-to-speech
    case file(String)       // path to audio file

    var id: String {
        switch self {
        case .system(let n): return "sys:\(n)"
        case .say(let t):    return "say:\(t)"
        case .file(let p):   return "file:\(p)"
        }
    }

    var label: String {
        switch self {
        case .system(let n): return "🔊 \(n)"
        case .say(let t):    return "🗣 \"\(t)\""
        case .file(let p):   return "📁 \(URL(fileURLWithPath: p).lastPathComponent)"
        }
    }

    func play() {
        switch self {
        case .system(let name):
            NSSound(named: .init(rawValue: name))?.play()
        case .say(let text):
            let t = Process()
            t.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            t.arguments = ["-v", "Samantha", text]
            try? t.run()
        case .file(let path):
            NSSound(contentsOfFile: path, byReference: false)?.play()
        }
    }
}

// ── Built-in libraries ────────────────────────────────────────

let systemSounds: [Sound] = [
    "Basso","Blow","Bottle","Frog","Funk","Glass",
    "Hero","Morse","Ping","Pop","Purr","Sosumi","Submarine","Tink"
].map { .system($0) }

// curated TTS phrases — feel free to add more in ContentView
let sayPresets: [Sound] = [
    "bye",
    "meow",
    "ow",
    "oh my god",
    "what the fuck",
    "spank me harder",
    "yes daddy",
    "ouch that hurt",
    "stop it",
    "do it again"
].map { .say($0) }

// ── Settings model ────────────────────────────────────────────

struct Settings {
    var rollLow:   Double = 10
    var rollHigh:  Double = 35
    var shakeLow:  Double = 0.15
    var shakeHigh: Double = 0.60
    var cooldown:  Double = 1.5

    var sounds: [Trigger: Sound] = [
        .rollLow:   .system("Purr"),
        .rollHigh:  .say("bye"),
        .shakeLow:  .say("ow"),
        .shakeHigh: .say("spank me harder"),
    ]
}
