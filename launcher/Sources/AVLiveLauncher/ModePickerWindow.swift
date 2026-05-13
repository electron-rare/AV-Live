import AppKit
import SwiftUI

/// Fenetre modale affichee au demarrage pour choisir le mode (Full /
/// Data-only). L'utilisateur peut cocher "ne plus afficher" : la
/// preference est persistee dans UserDefaults (cle `skipModePicker`).
struct ModePickerView: View {
    @ObservedObject var processManager: ProcessManager
    let onChoice: (LaunchMode) -> Void
    @State private var skipNextTime: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AV-Live")
                .font(.system(size: 22, weight: .semibold))
            Text("Quel mode lancer ?")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ModeCard(
                    title: "Full AV-Live",
                    subtitle: "SC + oscope-of + web UI + data_feeds",
                    icon: "waveform.path.ecg.rectangle",
                    color: .accentColor
                ) {
                    finish(.full)
                }
                ModeCard(
                    title: "Data-only",
                    subtitle: "SC + oscope-of + data_feeds (pose YOLO)\nPas de web UI, pas d'album",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .green
                ) {
                    finish(.dataOnly)
                }
            }

            Divider()

            Toggle("Ne plus afficher (utilisera le dernier mode choisi)",
                   isOn: $skipNextTime)
                .font(.caption)
        }
        .padding(24)
        .frame(width: 520)
        .onAppear {
            // Pre-coche selon la valeur persistee
            skipNextTime = UserDefaults.standard.bool(forKey: "skipModePicker")
        }
    }

    private func finish(_ choice: LaunchMode) {
        processManager.mode = choice
        UserDefaults.standard.set(skipNextTime, forKey: "skipModePicker")
        onChoice(choice)
    }
}

private struct ModeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
