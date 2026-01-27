import SwiftUI

/// View extension for hover scale effect
extension View {
    func hoverScale() -> some View {
        modifier(HoverScaleModifier())
    }
}

/// Modifier that adds subtle scale effects on hover and press
struct HoverScaleModifier: ViewModifier {
    @State private var isHovering = false
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : (isHovering ? 1.02 : 1.0))
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

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
            .hoverScale()

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
            .hoverScale()
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
