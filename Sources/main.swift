import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let brightnessUp = 2
    private static let brightnessDown = 3
    private static let auxControlButtons: Int16 = 8
    private static let systemDefinedEvent = 14

    private var keyTap: CFMachPort?
    private var statusItem: NSStatusItem!
    private var night: NightMode!
    private let popover = NSPopover()
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Второй экземпляр спорил бы с первым за экран.
        let same = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        if same.contains(where: { $0.processIdentifier != getpid() }) {
            NSApp.terminate(nil)
            return
        }
        guard let screen = Screen() else {
            NSLog("DisplayServices is unavailable")
            NSApp.terminate(nil)
            return
        }
        night = NightMode(screen: screen)
        night.onChange = { [weak self] in self?.updateIcon() }

        let hosting = NSHostingController(rootView: PanelView(night: night))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        // Сами закрываем по клику снаружи: transient закрылся бы на нажатии и тут же открылся снова по иконке.
        popover.behavior = .applicationDefined

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(clicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon()

        installKeyTap()
        LoginItem.install()
    }

    func applicationWillTerminate(_ notification: Notification) {
        night?.exit()
    }

    @objc private func clicked() {
        if popover.isShown { closePanel() } else { openPanel() }
    }

    private func openPanel() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        popover.performClose(nil)
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    // Глобальный монитор NSEvent клавиш яркости не видит, а прослушивающий перехват видит.
    private func installKeyTap() {
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = delegate.keyTap { CGEvent.tapEnable(tap: tap, enable: true) }
            } else if let nsEvent = NSEvent(cgEvent: event) {
                delegate.handleSystemEvent(nsEvent)
            }
            return Unmanaged.passUnretained(event)
        }
        keyTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                   eventsOfInterest: CGEventMask(1 << AppDelegate.systemDefinedEvent),
                                   callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let keyTap else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, keyTap, 0), .commonModes)
        CGEvent.tapEnable(tap: keyTap, enable: true)
    }

    private func handleSystemEvent(_ event: NSEvent) {
        guard event.subtype.rawValue == AppDelegate.auxControlButtons else { return }
        let key = (event.data1 & 0xFFFF0000) >> 16
        let flags = event.data1 & 0xFFFF
        let isDown = (flags & 0xFF00) >> 8 == 0x0A
        guard isDown, key == AppDelegate.brightnessUp || key == AppDelegate.brightnessDown else { return }
        night.brightnessKey(up: key == AppDelegate.brightnessUp)
    }

    private func updateIcon() {
        statusItem.button?.image = moon(filled: night.isOn)
        statusItem.button?.toolTip = night.isOn ? "Night Mode is on" : "Night Mode is off"
        statusItem.button?.setAccessibilityLabel(statusItem.button?.toolTip)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
