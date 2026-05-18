import Cocoa
import SwiftUI

/// Forces a regular, keyboard-focusable foreground app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }
}

@main
struct AVLiveBodyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup {
            Text("AVLiveBody")
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
