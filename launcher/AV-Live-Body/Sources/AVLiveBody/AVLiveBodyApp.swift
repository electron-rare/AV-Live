import Cocoa
import SwiftUI

@main
struct AVLiveBodyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Toggle Settings (S)") {
                    NotificationCenter.default.post(
                        name: .toggleSettings, object: nil)
                }
                .keyboardShortcut("s", modifiers: [])
            }
        }
    }
}

extension Notification.Name {
    static let toggleSettings = Notification.Name("avlive.toggleSettings")
}

struct ContentView: View {
    @StateObject private var renderer = MeshRenderer()
    @StateObject private var settings = RenderSettings()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            BodyView(renderer: renderer, settings: settings)
                .onAppear { renderer.startOSCServer() }
                .onReceive(NotificationCenter.default.publisher(
                    for: .toggleSettings)) { _ in
                    settings.showPanel.toggle()
                }
            // Bouton coin haut-droit pour ouvrir le panel
            Button(action: { settings.showPanel.toggle() }) {
                Image(systemName: settings.showPanel
                      ? "slider.horizontal.3"
                      : "slider.horizontal.below.rectangle")
                    .font(.system(size: 18, weight: .medium))
                    .padding(10)
                    .background(
                        Circle().fill(Color.black.opacity(0.45)))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(16)
            .help("Settings (S)")

            if settings.showPanel {
                SettingsPanel(settings: settings)
                    .transition(.move(edge: .trailing)
                        .combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: settings.showPanel)
    }
}
