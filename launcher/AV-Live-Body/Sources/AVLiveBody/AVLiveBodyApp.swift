import Cocoa
import SwiftUI

@main
struct AVLiveBodyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}

struct ContentView: View {
    @StateObject private var renderer = MeshRenderer()
    var body: some View {
        BodyView(renderer: renderer)
            .onAppear {
                renderer.startOSCServer()
            }
    }
}
