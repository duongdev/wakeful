import AppKit
import SwiftUI
import WakefulCore

struct LogsView: View {
    @State private var text = Log.shared.read()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(text.isEmpty ? String(localized: "No logs yet.") : text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            Divider()
            HStack {
                Button("Refresh") { text = Log.shared.read() }
                Button("Copy") { Self.copyToClipboard() }
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Log.shared.fileURL]) }
                Spacer()
                Button("Clear", role: .destructive) {
                    Log.shared.clear()
                    text = ""
                }
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 360)
    }

    static func copyToClipboard() {
        let header = "Wakeful \(Bundle.main.versionString), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(header + Log.shared.read(), forType: .string)
    }
}
