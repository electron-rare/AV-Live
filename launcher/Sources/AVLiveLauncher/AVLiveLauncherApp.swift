import AppKit
import SwiftUI

// MenuBar-only app : NSStatusItem + NSPopover. macOS 11+ compatible.
// LSUIElement = true (set in Info.plist) hides the dock icon.

@main
struct AVLiveLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty Settings scene so SwiftUI is happy. The real UI is the popover.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var logWindow: NSWindow?
    private var modePickerWindow: NSWindow?
    private let processManager = ProcessManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Status bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(
                    systemSymbolName: "waveform.path.ecg",
                    accessibilityDescription: "AV-Live"
                )
            } else {
                button.title = "AV"
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // Popover with the SwiftUI menu content
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 320)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContent(
                processManager: processManager,
                openLogs: { [weak self] in self?.showLogs() }
            )
        )

        // Mode picker au boot : si skipModePicker est faux, on demande a
        // l'utilisateur. Sinon on enchaine direct avec le mode persiste.
        let skipPicker = UserDefaults.standard.bool(forKey: "skipModePicker")
        if skipPicker {
            if processManager.autoStart {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.processManager.startAll()
                }
            }
        } else {
            showModePicker()
        }

        // Watch the sentinel file written by the web bridge's
        // /control/rebootSclang handler — restarts sclang when touched.
        processManager.startSentinelWatcher()
    }

    private func showModePicker() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "AV-Live — choisir le mode"
        w.center()
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.contentViewController = NSHostingController(
            rootView: ModePickerView(
                processManager: processManager,
                onChoice: { [weak self, weak w] _ in
                    w?.close()
                    self?.modePickerWindow = nil
                    if let pm = self?.processManager, pm.autoStart {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            pm.startAll()
                        }
                    }
                }
            )
        )
        modePickerWindow = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        processManager.stopAll()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showLogs() {
        if let w = logWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "AV-Live Logs"
        w.center()
        w.contentViewController = NSHostingController(
            rootView: LogView(processManager: processManager)
        )
        w.isReleasedWhenClosed = false
        logWindow = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
