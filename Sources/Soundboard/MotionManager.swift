import IOKit
import Foundation

enum Trigger: String, CaseIterable, Identifiable {
    case rollLow   = "Gentle Tilt"
    case rollHigh  = "Big Tilt"
    case shakeLow  = "Small Shake"
    case shakeHigh = "Big Shake"
    var id: String { rawValue }
}

class MotionManager: ObservableObject {
    @Published var roll:      Double = 0
    @Published var delta:     Double = 0
    @Published var available: Bool   = false
    @Published var running:   Bool   = false
    @Published var sensorMode: String = "—"

    var settings: Settings = Settings()
    var onTrigger: ((Trigger) -> Void)?

    private var sms:        SMSReader?
    private var timer:      Timer?
    private var px = 0.0, py = 0.0, pz = 0.0
    private var lastFired = Date.distantPast
    private var simPhase  = 0.0

    init() {
        if let reader = SMSReader() {
            sms       = reader
            available = true
            sensorMode = "SMS sensor (IOKit)"
        } else {
            // No SMS — use simulation so the UI is still testable
            available  = true
            sensorMode = "Simulation (no sensor found)"
        }
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
            self?.tick()
        }
        running = true
    }

    func stop() { timer?.invalidate(); timer = nil; running = false }

    // Manually fire a trigger (for the Test button in the UI)
    func test(_ trigger: Trigger) {
        settings.sounds[trigger]?.play()
    }

    private func tick() {
        let (x, y, z): (Double, Double, Double)

        if let reading = sms?.read() {
            (x, y, z) = reading
        } else {
            // Gentle sine-wave simulation so the live readout moves
            simPhase += 0.05
            x = sin(simPhase) * 0.08
            y = cos(simPhase * 0.7) * 0.06
            z = 1.0
        }

        process(x: x, y: y, z: z)
    }

    private func process(x: Double, y: Double, z: Double) {
        let r = abs(atan2(x, z) * (180 / .pi))
        let d = abs(x - px) + abs(y - py) + abs(z - pz)

        roll  = r
        delta = d
        px = x; py = y; pz = z

        let now = Date()
        guard now.timeIntervalSince(lastFired) >= settings.cooldown else { return }

        let hit: Trigger? =
            r >= settings.rollHigh  ? .rollHigh  :
            r >= settings.rollLow   ? .rollLow   :
            d >= settings.shakeHigh ? .shakeHigh :
            d >= settings.shakeLow  ? .shakeLow  : nil

        if let hit {
            lastFired = now
            onTrigger?(hit)
        }
    }
}

// ── IOKit Sudden Motion Sensor (Intel Macs) ───────────────────

private class SMSReader {
    private var connection: io_connect_t = 0

    init?() {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("SMCMotionSensor")
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else {
            return nil
        }
    }

    deinit { if connection != 0 { IOServiceClose(connection) } }

    func read() -> (x: Double, y: Double, z: Double)? {
        var input  = [UInt8](repeating: 0, count: 40)
        var output = [UInt8](repeating: 0, count: 40)
        var outSize = 40

        let kr = IOConnectCallStructMethod(
            connection, 5,
            &input,  input.count,
            &output, &outSize
        )
        guard kr == KERN_SUCCESS else { return nil }

        func i16(_ lo: UInt8, _ hi: UInt8) -> Double {
            Double(Int16(bitPattern: UInt16(lo) | (UInt16(hi) << 8)))
        }
        let scale = 250.0
        return (
            x: i16(output[0], output[1]) / scale,
            y: i16(output[2], output[3]) / scale,
            z: i16(output[4], output[5]) / scale
        )
    }
}
