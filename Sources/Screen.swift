import CoreGraphics
import Foundation

// Яркость встроенного экрана — приватный DisplayServices. Ниже минимума — таблица гаммы, как у
// BetterDisplay: держится, пока жив процесс, при падении приложения экран возвращается сам.
final class Screen {
    // Нижний шаг клавиш яркости, 1/16. По таблице панели это 1 нит, а 0 — подсветка выключена совсем.
    static let minimum: Float = 1.0 / 16
    private static let epsilon: Float = 0.002

    private typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Set = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let get: Get
    private let set: Set

    init?() {
        guard let lib = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
              let g = dlsym(lib, "DisplayServicesGetBrightness"),
              let s = dlsym(lib, "DisplayServicesSetBrightness") else { return nil }
        get = unsafeBitCast(g, to: Get.self)
        set = unsafeBitCast(s, to: Set.self)
    }

    private var displays: [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    private var builtIn: CGDirectDisplayID? { displays.first { CGDisplayIsBuiltin($0) != 0 } }

    var brightness: Float? {
        guard let id = builtIn else { return nil }
        var value: Float = 0
        return get(id, &value) == 0 ? value : nil
    }

    var isHeldAtMinimum: Bool { abs((brightness ?? 1) - Screen.minimum) <= Screen.epsilon }

    func setBrightness(_ value: Float) {
        if let id = builtIn { _ = set(id, value) }
    }

    // scale — множитель выхода: 1 без затемнения. Пишем, только если значение слетело.
    func holdGamma(_ scale: Float) {
        for id in displays {
            var rMin: CGGammaValue = 0, rMax: CGGammaValue = 0, rG: CGGammaValue = 0
            var gMin: CGGammaValue = 0, gMax: CGGammaValue = 0, gG: CGGammaValue = 0
            var bMin: CGGammaValue = 0, bMax: CGGammaValue = 0, bG: CGGammaValue = 0
            let read = CGGetDisplayTransferByFormula(id, &rMin, &rMax, &rG, &gMin, &gMax, &gG, &bMin, &bMax, &bG)
            if read == .success, abs(rMax - scale) < 0.001, abs(gMax - scale) < 0.001, abs(bMax - scale) < 0.001 { continue }
            CGSetDisplayTransferByFormula(id, 0, scale, 1, 0, scale, 1, 0, scale, 1)
        }
    }

    func restoreGamma() { CGDisplayRestoreColorSyncSettings() }
}
