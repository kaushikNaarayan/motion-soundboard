import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var motion = MotionManager()
    @State private var settings = Settings()
    @State private var lastHit: Trigger? = nil

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    soundSection
                    thresholdSection
                }
                .padding()
            }
        }
        .frame(width: 440)
        .onAppear(perform: setup)
    }

    // ── Status bar ─────────────────────────────────────────────

    var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(motion.running ? .green : .red)
                .frame(width: 9, height: 9)
            Text(motion.running ? "Active" : "No sensor")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Roll \(Int(motion.roll))°")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text("Shake \(String(format: "%.2f", motion.delta))g")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // ── Sound assignments ──────────────────────────────────────

    var soundSection: some View {
        GroupBox {
            VStack(spacing: 10) {
                ForEach(Trigger.allCases) { trigger in
                    SoundRow(
                        trigger: trigger,
                        sound: bindSound(trigger),
                        isActive: lastHit == trigger
                    )
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Sound Assignments", systemImage: "waveform")
        }
    }

    // ── Thresholds ─────────────────────────────────────────────

    var thresholdSection: some View {
        GroupBox {
            VStack(spacing: 10) {
                SliderRow("Roll low",   $settings.rollLow,   5...80,   "%.0f°")
                SliderRow("Roll high",  $settings.rollHigh,  5...80,   "%.0f°")
                Divider()
                SliderRow("Shake low",  $settings.shakeLow,  0.05...1, "%.2fg")
                SliderRow("Shake high", $settings.shakeHigh, 0.05...1, "%.2fg")
                Divider()
                SliderRow("Cooldown",   $settings.cooldown,  0.3...5,  "%.1fs")
            }
            .padding(.vertical, 4)
        } label: {
            Label("Thresholds", systemImage: "slider.horizontal.3")
        }
        .onChange(of: settings.rollLow)   { _ in push() }
        .onChange(of: settings.rollHigh)  { _ in push() }
        .onChange(of: settings.shakeLow)  { _ in push() }
        .onChange(of: settings.shakeHigh) { _ in push() }
        .onChange(of: settings.cooldown)  { _ in push() }
    }

    // ── Helpers ────────────────────────────────────────────────

    func setup() {
        push()
        motion.onTrigger = { trigger in
            settings.sounds[trigger]?.play()
            lastHit = trigger
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if lastHit == trigger { lastHit = nil }
            }
        }
        motion.start()
    }

    func push() { motion.settings = settings }

    func bindSound(_ trigger: Trigger) -> Binding<Sound> {
        Binding(
            get: { settings.sounds[trigger] ?? .system("Purr") },
            set: { settings.sounds[trigger] = $0; push() }
        )
    }
}

// ── Sound row ──────────────────────────────────────────────────

struct SoundRow: View {
    let trigger: Trigger
    @Binding var sound: Sound
    let isActive: Bool

    @State private var customText = ""
    @State private var showCustomSheet = false

    var body: some View {
        HStack(spacing: 8) {
            // Trigger label — lights up orange when fired
            Text(trigger.rawValue)
                .frame(width: 105, alignment: .leading)
                .font(.subheadline)
                .foregroundStyle(isActive ? Color.orange : .primary)
                .fontWeight(isActive ? .semibold : .regular)
                .animation(.easeInOut(duration: 0.15), value: isActive)

            // Sound picker
            Menu(sound.label) {
                Section("System Sounds") {
                    ForEach(systemSounds) { s in
                        Button(s.label) { sound = s }
                    }
                }
                Section("Say (TTS)") {
                    ForEach(sayPresets) { s in
                        Button(s.label) { sound = s }
                    }
                    Divider()
                    Button("🗣 Custom phrase…") { showCustomSheet = true }
                }
                Section("Audio File") {
                    Button("📁 Choose file…") { pickFile() }
                }
            }
            .frame(maxWidth: .infinity)

            // Test button
            Button("▶") { sound.play() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .sheet(isPresented: $showCustomSheet) {
            VStack(spacing: 16) {
                Text("Custom phrase").font(.headline)
                TextField("type anything…", text: $customText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
                HStack {
                    Button("Cancel") { showCustomSheet = false }
                    Button("Set") {
                        if !customText.isEmpty { sound = .say(customText) }
                        showCustomSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
    }

    func pickFile() {
        let panel = NSOpenPanel()
        panel.message = "Choose an audio file"
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            sound = .file(url.path)
        }
    }
}

// ── Slider row ─────────────────────────────────────────────────

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let fmt: String

    init(_ label: String, _ value: Binding<Double>,
         _ range: ClosedRange<Double>, _ fmt: String) {
        self.label = label; self._value = value
        self.range = range; self.fmt = fmt
    }

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 85, alignment: .leading)
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $value, in: range)
            Text(String(format: fmt, value))
                .font(.caption.monospaced())
                .frame(width: 52, alignment: .trailing)
        }
    }
}
