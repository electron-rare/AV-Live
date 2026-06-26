// avlivebody-mac/Sources/AVLiveBody/SettingsPanel.swift
import SwiftUI

/// Collapsible right-side control panel bound to RenderSettings.
struct SettingsPanel: View {
    @ObservedObject var settings: RenderSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Reglages").font(.headline)

                group("Couches") {
                    Toggle("Squelette", isOn: $settings.showSkeleton)
                    Toggle("Mesh", isOn: $settings.showMesh)
                    Toggle("Video", isOn: $settings.showVideo)
                }

                group("Mesh") {
                    Toggle("Metallique", isOn: $settings.meshMetallic)
                    slider("Rugosite", $settings.meshRoughness,
                           0...1)
                }

                group("Lumieres") {
                    slider("Principale", $settings.keyIntensity,
                           0...10000)
                    slider("Remplissage", $settings.fillIntensity,
                           0...10000)
                    slider("Contre-jour", $settings.rimIntensity,
                           0...10000)
                }

                group("Vue") {
                    slider("Champ de vision", $settings.fieldOfView,
                           20...120)
                    slider("Opacite video", $settings.videoOpacity,
                           0...1)
                }

                group("Scene") {
                    Toggle("Fond shader", isOn: $settings.showScene)
                    Picker("Mode", selection: $settings.vizMode) {
                        ForEach(0..<10, id: \.self) { i in
                            Text(Self.modeName(i)).tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(16)
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }

    static func modeName(_ i: Int) -> String {
        let n = ["storm","tunnel","plasma","kaleido","voronoi",
                 "metaballs","starfield","bars","hands3d","openpos"]
        return n.indices.contains(i) ? "\(i) \(n[i])" : "\(i)"
    }

    @ViewBuilder
    private func group(_ title: String,
                       @ViewBuilder _ content: () -> some View)
        -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            content()
        }
    }

    private func slider(_ label: String,
                        _ value: Binding<Double>,
                        _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
