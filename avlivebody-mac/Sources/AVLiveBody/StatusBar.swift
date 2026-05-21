import SwiftUI

/// A thin overlay showing the USB connection state.
struct StatusBar: View {
    @ObservedObject var consumer: USBSkeletonConsumer

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(consumer.connected ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
            Text(consumer.connected
                 ? "iPhone connected (USB)"
                 : "waiting for iPhone…")
                .font(.caption)
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(8)
        .background(.black.opacity(0.5))
    }
}
