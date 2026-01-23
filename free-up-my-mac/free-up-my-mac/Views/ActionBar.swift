import SwiftUI

/// Bottom action bar with selection count and trash button
struct ActionBar: View {
    let selectedCount: Int
    let selectedSize: Int64
    let isProcessing: Bool
    let onTrash: () -> Void
    let onNewScan: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // New scan button
            Button {
                onNewScan()
            } label: {
                Label("New Scan", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)

            Spacer()

            // Selection summary
            if selectedCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(selectedCount) file\(selectedCount == 1 ? "" : "s") selected")
                        .fontWeight(.medium)

                    Text(ByteFormatter.format(selectedSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Trash button
            Button {
                onTrash()
            } label: {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selectedCount == 0 || isProcessing)
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

#Preview("No Selection") {
    ActionBar(
        selectedCount: 0,
        selectedSize: 0,
        isProcessing: false,
        onTrash: {},
        onNewScan: {}
    )
    .frame(width: 800)
}

#Preview("With Selection") {
    ActionBar(
        selectedCount: 12,
        selectedSize: 1024 * 1024 * 150,
        isProcessing: false,
        onTrash: {},
        onNewScan: {}
    )
    .frame(width: 800)
}

#Preview("Processing") {
    ActionBar(
        selectedCount: 12,
        selectedSize: 1024 * 1024 * 150,
        isProcessing: true,
        onTrash: {},
        onNewScan: {}
    )
    .frame(width: 800)
}
