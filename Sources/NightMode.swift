import AppKit
import Combine

// Состояние режима: что сохранить при входе, что держать, куда вернуться при выходе.
final class NightMode: ObservableObject {
    // Доля ниже системного минимума. У экрана потолок ниже: гамма в ноль — это черный экран.
    static let screenRange: ClosedRange<Double> = 0...0.8
    static let keyboardRange: ClosedRange<Double> = 0...0.9

    @Published private(set) var isOn = false
    @Published var screenDim: Double {
        didSet {
            UserDefaults.standard.set(screenDim, forKey: "screenDim")
            hold()
        }
    }
    @Published var keyboardDim: Double {
        didSet {
            UserDefaults.standard.set(keyboardDim, forKey: "keyboardDim")
            keyboard?.fraction = 1 - keyboardDim
        }
    }

    private let screen: Screen
    private let backlight: Backlight?
    private let keyboard: KeyboardHold?
    private var saved: (screen: Float, keyboard: Float)?
    private var timer: Timer?
    private var asleep = false

    var onChange: (() -> Void)?

    init(screen: Screen) {
        self.screen = screen
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["screenDim": 0.3, "keyboardDim": 0.3])
        screenDim = defaults.double(forKey: "screenDim")
        keyboardDim = defaults.double(forKey: "keyboardDim")
        backlight = Backlight()
        keyboard = backlight.map { KeyboardHold(backlight: $0, fraction: 1 - defaults.double(forKey: "keyboardDim")) }

        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.sleep(true) }
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.sleep(false) }
        }
    }

    func enter() {
        guard !isOn else { return }
        let keyboardBefore = backlight?.brightness ?? 0
        saved = (max(screen.brightness ?? Screen.minimum, Screen.minimum), keyboardBefore)
        isOn = true
        hold()
        // Выключенную вручную клавиатуру не зажигаем. Ноль при автоподстройке — это простой или светлая комната.
        if keyboardBefore > 0 || backlight?.isAutoBrightnessEnabled == true { keyboard?.start() }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.hold() }
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
        onChange?()
    }

    func exit() {
        guard let saved else { return }
        self.saved = nil
        isOn = false
        timer?.invalidate()
        timer = nil
        keyboard?.stop()
        screen.restoreGamma()
        // Сначала подстройка, потом значение: иначе она сразу уводит клавиатуру от выставленного.
        keyboard?.resumeAutoBrightness()
        screen.setBrightness(saved.screen)
        if saved.keyboard > 0 { backlight?.set(saved.keyboard) }
        onChange?()
    }

    func toggle() {
        if isOn { exit() } else { enter() }
    }

    // Страховка на случай, когда экрана не видно: клавиша прибавления яркости выключает режим.
    // Система по этой же клавише сдвинет яркость на шаг, поэтому значение ставим еще раз, с задержкой.
    func brightnessKey(up: Bool) {
        guard isOn else { return }
        let target = saved?.screen
        if up { exit() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            if self.isOn {
                self.hold()
            } else if let target {
                self.screen.setBrightness(target)
            }
        }
    }

    private func hold() {
        guard isOn, !asleep else { return }
        screen.holdGamma(Float(1 - screenDim))
        if !screen.isHeldAtMinimum { screen.setBrightness(Screen.minimum) }
    }

    private func sleep(_ on: Bool) {
        asleep = on
        keyboard?.suspend(on)
        if !on { hold() }
    }
}
