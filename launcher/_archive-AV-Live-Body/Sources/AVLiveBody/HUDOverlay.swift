import SwiftUI

/// HUD coin haut-gauche : mode actif, nb personnes, fps approx, et la
/// liste des touches actives (mapping clavier). Translucide, ne capte
/// pas les events souris.
struct HUDOverlay: View {
    @ObservedObject var settings: RenderSettings
    @ObservedObject var poseListener: PoseOSCListener

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Statut courant
            HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(poseListener.count > 0
                                     ? .green : .gray)
                Text("AV-Live-Body").bold()
                Text("\(settings.vizModeName) (#\(settings.vizMode))")
                    .foregroundColor(.pink)
                Spacer()
                Text("pose: \(poseListener.count)")
                    .foregroundColor(.white.opacity(0.7))
            }
            Divider().background(Color.white.opacity(0.2))

            // Liste des touches actives
            VStack(alignment: .leading, spacing: 2) {
                hudKey("S", "ouvre / ferme le panel reglages")
                hudKey("0..9", "viz mode (storm / ... / openpos)")
                hudKey("M", "toggle Maillage SMPL-X")
                hudKey("W", "toggle Fil de fer")
                hudKey("C", "toggle Webcam")
                hudKey("V", "toggle Scene Metal")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.white.opacity(0.75))

            // Position 3D de la 1ere personne (si detectee)
            if let first = poseListener.persons.values.first {
                Divider().background(Color.white.opacity(0.2))
                Text(String(format:
                    "head (%.2f, %.2f)  wristL (%.2f, %.2f)  wristR (%.2f, %.2f)",
                    first.head.x, first.head.y,
                    first.wristL.x, first.wristL.y,
                    first.wristR.x, first.wristR.y))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(12)
        .frame(maxWidth: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.55))
        )
        .padding(12)
        .allowsHitTesting(false)
    }

    private func hudKey(_ key: String, _ desc: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .frame(minWidth: 28, alignment: .leading)
                .foregroundColor(.pink)
            Text(desc)
        }
    }
}
