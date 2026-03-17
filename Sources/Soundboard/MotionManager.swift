import CoreMotion
import Foundation

enum Trigger: String, CaseIterable, Identifiable {
    case rollLow   = "Gentle Tilt"
    case rollHigh  = "Big Tilt"
    case shakeLow  = "Small Shake"
    case shakeHigh = "Big Shake"
    var id: String { rawValue }
}

class MotionManager: ObservableObject {
    private let cm = CMMotionManager()

    @Published var roll:  Double = 0
    @Published var delta: Double = 0
    @Published var available: Bool = false
    @Published var running: Bool = false

    var settings: Settings = Settings()
    var onTrigger: ((Trigger) -> Void)?

    private var px = 0.0, py = 0.0, pz = 0.0
    private var lastFired = Date.distantPast

    init() { available = cm.isAccelerometerAvailable }

    func start() {
        guard available else { return }
        cm.accelerometerUpdateInterval = 1.0 / 20
        cm.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data else { return }
            self.process(a)
        }
        running = true
    }

    func stop() { cm.stopAccelerometerUpdates(); running = false }

    private func process(_ a: CMAccelerometerData) {
        let r = abs(atan2(a.acceleration.x, a.acceleration.z) * (180 / .pi))
        let d = abs(a.acceleration.x - px)
              + abs(a.acceleration.y - py)
              + abs(a.acceleration.z - pz)

        roll  = r
        delta = d

        px = a.acceleration.x
        py = a.acceleration.y
        pz = a.acceleration.z

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
