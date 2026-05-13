import SwiftUI

/// Panneau de reglages visuels overlay. Affiche / cache via
/// settings.showPanel (toggle 'S' clavier ou bouton). Reglages
/// appliques en live au BodyView/ARView via les @Published.
struct SettingsPanel: View {
    @ObservedObject var settings: RenderSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                Divider().background(Color.white.opacity(0.2))
                layersSection
                Divider().background(Color.white.opacity(0.15))
                cameraSection
                Divider().background(Color.white.opacity(0.15))
                meshSection
                Divider().background(Color.white.opacity(0.15))
                lightsSection
                Divider().background(Color.white.opacity(0.15))
                viewSection
            }
            .padding(16)
        }
        .frame(width: 320, height: 620)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(20)
    }

    private var header: some View {
        HStack {
            Text("Réglages AV-Live-Body")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: { settings.showPanel = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Fermer (S)")
        }
    }

    private var layersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Couches")
            layerRow(icon: "video.fill",
                     label: "Webcam",
                     isOn: $settings.showCamera)
            layerRow(icon: "person.fill",
                     label: "Maillage SMPL-X",
                     isOn: $settings.showMesh)
            layerRow(icon: "circle.dotted",
                     label: "Fil de fer",
                     isOn: $settings.showWireframe)
            layerRow(icon: "figure.stand",
                     label: "Squelette (articulations)",
                     isOn: $settings.showSkeleton)
        }
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Webcam")
            slider("Opacité",
                   value: $settings.camOpacity,
                   in: 0...1, format: "%.2f")
        }
    }

    private var meshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Maillage")
            Toggle("Métallique", isOn: $settings.meshMetallic)
                .foregroundColor(.white)
            slider("Rugosité",
                   value: $settings.meshRoughness,
                   in: 0...1, format: "%.2f")
        }
    }

    private var lightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Lumières")
            slider("Principale (chaude, avant-droite)",
                   value: $settings.keyIntensity,
                   in: 0...10000, format: "%.0f")
            slider("Remplissage (froide, avant-gauche)",
                   value: $settings.fillIntensity,
                   in: 0...10000, format: "%.0f")
            slider("Contre-jour (arrière)",
                   value: $settings.rimIntensity,
                   in: 0...10000, format: "%.0f")
        }
    }

    private var viewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Vue")
            slider("Champ de vision",
                   value: $settings.fieldOfView,
                   in: 20...120, format: "%.0f°")
            slider("Luminosité du fond",
                   value: $settings.bgBrightness,
                   in: 0...0.5, format: "%.2f")
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.2)
            .foregroundColor(.white.opacity(0.5))
    }

    private func layerRow(icon: String, label: String,
                          isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(isOn.wrappedValue
                                 ? .pink
                                 : .white.opacity(0.4))
            Text(label)
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private func slider(_ label: String,
                        value: Binding<Double>,
                        in range: ClosedRange<Double>,
                        format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.6))
            }
            Slider(value: value, in: range)
                .accentColor(.pink)
        }
    }
}
