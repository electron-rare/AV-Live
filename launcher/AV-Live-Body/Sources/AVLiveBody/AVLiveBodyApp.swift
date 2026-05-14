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
            // Pas de keyboardShortcut sans modifier : ca beep si NSWindow
            // n'a pas la cible. On utilise un NSEvent.addLocalMonitor
            // dans BodyView pour capter S/C/V/M/W/0-9 et consommer
            // l'event proprement. Les menu items restent dispo via le
            // menu superieur, avec Cmd-modified shortcuts conventionnels.
            CommandGroup(replacing: .appSettings) {
                Button("Toggle Settings") {
                    NotificationCenter.default.post(
                        name: .toggleSettings, object: nil)
                }.keyboardShortcut("s", modifiers: [.command])
            }
            CommandMenu("Calques") {
                Button("Toggle Webcam") {
                    NotificationCenter.default.post(
                        name: .toggleLayer, object: "camera")
                }.keyboardShortcut("c", modifiers: [.command])
                Button("Toggle Scene Metal") {
                    NotificationCenter.default.post(
                        name: .toggleLayer, object: "scene")
                }.keyboardShortcut("v", modifiers: [.command])
                Button("Toggle Maillage SMPL-X") {
                    NotificationCenter.default.post(
                        name: .toggleLayer, object: "mesh")
                }.keyboardShortcut("m", modifiers: [.command])
                Button("Toggle Fil de fer") {
                    NotificationCenter.default.post(
                        name: .toggleLayer, object: "wireframe")
                }.keyboardShortcut("w", modifiers: [.command])
            }
            CommandMenu("Modes visuels") {
                let names = ["storm", "tunnel", "plasma", "kaleido",
                             "voronoi", "metaballs", "starfield",
                             "bars", "hands3d", "openpos"]
                ForEach(0..<10) { i in
                    Button("\(i) — \(names[i])") {
                        NotificationCenter.default.post(
                            name: .setVizMode, object: i)
                    }.keyboardShortcut(
                        KeyEquivalent(Character(String(i))),
                        modifiers: [.command])
                }
            }
        }
    }
}

extension Notification.Name {
    static let toggleSettings = Notification.Name("avlive.toggleSettings")
    static let toggleLayer = Notification.Name("avlive.toggleLayer")
    static let setVizMode = Notification.Name("avlive.setVizMode")
}

struct ContentView: View {
    @StateObject private var renderer = MeshRenderer()
    @StateObject private var settings = RenderSettings()
    @StateObject private var poseListener = PoseOSCListener()
    @StateObject private var arkitListener = ArkitOSCListener()
    @StateObject private var dataFeeds = DataFeedsOSCListener()

    var body: some View {
        ZStack(alignment: .topLeading) {
            BodyView(renderer: renderer, settings: settings,
                     poseListener: poseListener,
                     arkitListener: arkitListener)
                .onAppear {
                    renderer.startOSCServer()
                    poseListener.start()
                    arkitListener.start()
                    dataFeeds.start()
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: .toggleSettings)) { _ in
                    settings.showPanel.toggle()
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: .toggleLayer)) { note in
                    handleLayerToggle(note)
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: .setVizMode)) { note in
                    if let n = note.object as? Int { settings.vizMode = n }
                }

            // Face + hand overlay 2D Canvas retire : les landmarks sont
            // maintenant integres au squelette 3D RealityKit (cf.
            // Skeleton3DRenderer.applyFace/applyHands).

            // HUD coin haut-gauche : mode + touches + pose
            HUDOverlay(settings: settings, poseListener: poseListener)

            // Data feeds HUD : telemetrie open-data (eco2mix, velib, ...)
            VStack {
                Spacer()
                HStack {
                    DataHUDOverlay(data: dataFeeds, settings: settings)
                    Spacer()
                }
            }

            // Bouton settings coin haut-droit
            HStack {
                Spacer()
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
            }

            if settings.showPanel {
                HStack {
                    Spacer()
                    SettingsPanel(settings: settings)
                        .transition(.move(edge: .trailing)
                            .combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: settings.showPanel)
    }

    private func handleLayerToggle(_ note: Notification) {
        guard let key = note.object as? String else { return }
        switch key {
        case "camera": settings.showCamera.toggle()
        case "scene": settings.showScene.toggle()
        case "mesh": settings.showMesh.toggle()
        case "wireframe": settings.showWireframe.toggle()
        default: break
        }
    }
}
