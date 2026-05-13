import SwiftUI

/// Panneau de reglages visuels overlay. Affiche / cache via
/// settings.showPanel (toggle 'S' clavier ou bouton). Reglages
/// appliques en live au BodyView/ARView via les @Published.
struct SettingsPanel: View {
    @ObservedObject var settings: RenderSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("AV-Live-Body settings")
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
            Divider().background(Color.white.opacity(0.2))

            // ---------- Camera ----------
            Group {
                Toggle("Webcam visible", isOn: $settings.showCamera)
                    .foregroundColor(.white)
                slider("Cam opacity",
                       value: $settings.camOpacity,
                       in: 0...1, format: "%.2f")
            }
            Divider().background(Color.white.opacity(0.15))

            // ---------- Background ----------
            slider("Background brightness",
                   value: $settings.bgBrightness,
                   in: 0...0.5, format: "%.2f")
            Divider().background(Color.white.opacity(0.15))

            // ---------- Mesh ----------
            Group {
                Toggle("Mesh visible", isOn: $settings.showMesh)
                    .foregroundColor(.white)
                Toggle("Metallic", isOn: $settings.meshMetallic)
                    .foregroundColor(.white)
                slider("Roughness",
                       value: $settings.meshRoughness,
                       in: 0...1, format: "%.2f")
            }
            Divider().background(Color.white.opacity(0.15))

            // ---------- Lights ----------
            Group {
                slider("Key light",
                       value: $settings.keyIntensity,
                       in: 0...10000, format: "%.0f")
                slider("Fill light",
                       value: $settings.fillIntensity,
                       in: 0...10000, format: "%.0f")
                slider("Rim light",
                       value: $settings.rimIntensity,
                       in: 0...10000, format: "%.0f")
            }
            Divider().background(Color.white.opacity(0.15))

            // ---------- Camera ----------
            slider("FOV (deg)",
                   value: $settings.fieldOfView,
                   in: 20...120, format: "%.0f")
        }
        .padding(16)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(20)
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
