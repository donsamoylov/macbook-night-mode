import AppKit

// macOS зажимает ненулевую яркость на полу PWM, но плавный переход идет по сырому duty до нуля.
// Ведем переход вниз, читаем живой duty и держим его на цели медленными переходами.
// Способ и логика удержания — из Lowlight (Isaac Harper, MIT).
final class KeyboardHold {
    private static let approachMs = 400.0

    private enum Motion { case none, fastDown, fastUp, slowDown }

    private let backlight: Backlight
    // Доля от системного минимума, которую держим.
    var fraction: Double {
        didSet { targetDuty = duty() }
    }
    private var timer: Timer?
    private var motion: Motion = .none
    private var activity: NSObjectProtocol?
    private var targetDuty = 0
    private var suspended = false
    private var waitingForWake = false
    private var offSince: Date?
    private(set) var isHolding = false

    private var floorDuty = UserDefaults.standard.object(forKey: "floorDuty") as? Int ?? 54 {
        didSet { UserDefaults.standard.set(floorDuty, forKey: "floorDuty") }
    }
    private var needsFloorReading = false
    private var floorCandidate: Int?

    private var pausedAutoBrightness: Bool {
        get { UserDefaults.standard.bool(forKey: "pausedAutoBrightness") }
        set { UserDefaults.standard.set(newValue, forKey: "pausedAutoBrightness") }
    }

    init(backlight: Backlight, fraction: Double) {
        self.backlight = backlight
        self.fraction = fraction
        // После падения приложения подстройка могла остаться на паузе.
        resumeAutoBrightness()
    }

    func start() {
        guard !isHolding else { return }
        isHolding = true
        if !pausedAutoBrightness, backlight.isAutoBrightnessEnabled {
            backlight.isAutoBrightnessEnabled = false
            pausedAutoBrightness = true
        }
        backlight.set(Backlight.floorBrightness)
        needsFloorReading = true
        floorCandidate = nil
        motion = .none
        targetDuty = duty()
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Holding keyboard backlight")
        schedule(0.25)
    }

    func stop() {
        guard isHolding else { return }
        isHolding = false
        waitingForWake = false
        offSince = nil
        timer?.invalidate()
        timer = nil
        motion = .none
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
    }

    func resumeAutoBrightness() {
        guard pausedAutoBrightness else { return }
        backlight.isAutoBrightnessEnabled = true
        pausedAutoBrightness = false
    }

    func suspend(_ on: Bool) {
        suspended = on
        guard isHolding else { return }
        if on {
            timer?.invalidate()
            timer = nil
        } else {
            motion = .none
            schedule(0.5)
        }
    }

    private func duty() -> Int {
        max(2, min(floorDuty - 1, Int((fraction * Double(floorDuty)).rounded())))
    }

    private func schedule(_ seconds: TimeInterval) {
        timer?.invalidate()
        guard !suspended else { timer = nil; return }
        let t = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in self?.tick() }
        t.tolerance = seconds * 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        timer = nil
        guard isHolding else { return }

        if backlight.isLidClosed {
            motion = .fastUp
            schedule(0.5)
            return
        }

        // Погасла по простою: ждем касания, потом заново встаем на пол и идем вниз.
        if backlight.duty == nil, backlight.isIdleDimmed {
            waitingForWake = true
            motion = .none
            schedule(0.25)
            return
        }
        if waitingForWake {
            waitingForWake = false
            backlight.set(Backlight.floorBrightness)
            needsFloorReading = true
            floorCandidate = nil
            schedule(0.5)
            return
        }

        // Яркость подняли руками в Пункте управления: клавиатуру отдаем, экран продолжает держаться.
        // Ноль сюда не считается: его дает и гашение по простою, а ручное выключение ловится ниже по duty.
        let stored = backlight.brightness
        if stored > Backlight.floorBrightness + 0.0001 && abs(stored - backlight.lastTarget) > 0.0001 {
            stop()
            resumeAutoBrightness()
            return
        }

        guard let d = backlight.duty else {
            if motion == .fastDown || motion == .fastUp {
                // Проскочили цель и погасли: поднимаемся обратно.
                fade(.fastUp, to: Backlight.floorBrightness, ms: 1_000)
                schedule(0.1)
            } else if let since = offSince, Date().timeIntervalSince(since) > 1 {
                // Выключили вручную: не спорим.
                stop()
                resumeAutoBrightness()
            } else {
                if offSince == nil { offSince = Date() }
                schedule(0.3)
            }
            return
        }
        offSince = nil

        if needsFloorReading {
            guard d == floorCandidate else {
                floorCandidate = d
                schedule(0.15)
                return
            }
            needsFloorReading = false
            if d > 10 { floorDuty = d }
            targetDuty = duty()
        }

        let err = d - targetDuty
        if err > 0 {
            let ms = Int(KeyboardHold.approachMs * Double(d) / Double(err))
            fade(.fastDown, to: 0, ms: ms)
            schedule(0.1)
        } else if err < 0 {
            let span = max(1, floorDuty - d)
            let ms = Int(KeyboardHold.approachMs * Double(span) / Double(-err))
            fade(.fastUp, to: Backlight.floorBrightness, ms: ms)
            schedule(0.1)
        } else {
            if motion != .slowDown { fade(.slowDown, to: 0, ms: Backlight.slowestFadeMs) }
            schedule(0.3)
        }
    }

    private func fade(_ m: Motion, to value: Float, ms: Int) {
        backlight.fade(to: value, ms: min(max(ms, 20), Backlight.slowestFadeMs), commit: false)
        motion = m
    }
}
