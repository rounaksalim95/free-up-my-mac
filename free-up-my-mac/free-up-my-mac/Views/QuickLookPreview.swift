import SwiftUI
import QuickLookUI

/// QuickLook preview panel wrapper for SwiftUI
struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView()
        previewView.previewItem = url as QLPreviewItem
        return previewView
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as QLPreviewItem
    }
}

/// Sheet wrapper for QuickLook preview with controls
struct QuickLookSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.headline)
                    Text(url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Preview
            QuickLookPreview(url: url)
                .frame(minWidth: 500, minHeight: 300)
        }
    }
}

#Preview {
    // Note: Preview won't work without a real file
    QuickLookSheet(url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns"))
        .frame(width: 700, height: 500)
}
