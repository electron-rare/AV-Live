import SwiftUI

struct LogView: View {
    @ObservedObject var processManager: ProcessManager
    @State private var filter: String = ""
    @State private var autoScroll = true

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var filtered: [LogLine] {
        guard !filter.isEmpty else { return processManager.logs }
        return processManager.logs.filter {
            $0.text.localizedCaseInsensitiveContains(filter)
                || $0.source.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Filter", text: $filter)
                    .textFieldStyle(.roundedBorder)
                Toggle("Auto-scroll", isOn: $autoScroll)
                Button("Clear") { processManager.clearLogs() }
            }
            .padding(8)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(filtered) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(Self.timeFormatter.string(from: line.timestamp))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text(line.source)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(color(for: line.source))
                                    .frame(width: 70, alignment: .leading)
                                selectableText(line.text)
                                    .font(.system(.caption, design: .monospaced))
                            }
                            .id(line.id)
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: filtered.count) { _ in
                    if autoScroll, let last = filtered.last {
                        withAnimation(.linear(duration: 0.05)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func color(for source: String) -> Color {
        if source.hasPrefix("sclang") { return .blue }
        if source.hasPrefix("oscope") { return .purple }
        return .secondary
    }

    @ViewBuilder
    private func selectableText(_ s: String) -> some View {
        if #available(macOS 12.0, *) {
            Text(s).textSelection(.enabled)
        } else {
            Text(s)
        }
    }
}
