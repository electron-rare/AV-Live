import SwiftUI

/// Compact HUD overlay : per-feed counters + last sample chip.
struct DataHUDOverlay: View {
    @ObservedObject var data: DataFeedsOSCListener
    @ObservedObject var settings: RenderSettings

    var body: some View {
        if settings.showDataHUD {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(data.samples.keys.sorted(), id: \.self) { feed in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(freshColor(for: feed))
                            .frame(width: 6, height: 6)
                        Text(feed)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Text(summary(for: feed))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.4))
            .cornerRadius(6)
            .padding()
        }
    }

    private func freshColor(for feed: String) -> Color {
        let now = Date().timeIntervalSince1970
        let last = data.heartbeats[feed] ?? 0
        let age = now - last
        if age < 60 { return .green }
        if age < 600 { return .yellow }
        return .red
    }

    private func summary(for feed: String) -> String {
        let s = data.samples[feed] ?? [:]
        if let n = data.counts[feed] {
            return "\(s.count) keys / \(n)"
        }
        return "\(s.count) keys"
    }
}
