import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Folder selection area with NSOpenPanel and drag-drop support
struct FolderSelectionView: View {
    @Bindable var viewModel: ScanViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? Color.blue : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
                    )

                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(isTargeted ? .blue : .secondary)

                    Text("Drop folders here or click to select")
                        .foregroundStyle(.secondary)

                    Button("Choose Folders...") {
                        openFolderPanel()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(32)
            }
            .frame(height: 150)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
            }
            .onTapGesture {
                openFolderPanel()
            }

            // Selected folders
            if !viewModel.selectedFolders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Selected Folders")
                            .font(.headline)

                        Spacer()

                        Button("Clear All") {
                            viewModel.clearFolders()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }

                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.selectedFolders, id: \.self) { folder in
                            FolderChipView(folder: folder) {
                                viewModel.removeFolder(folder)
                            }
                        }
                    }
                }
            }
        }
    }

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.message = "Select folders to scan for duplicates"
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            for url in panel.urls {
                viewModel.addFolder(url)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true) {
                        var isDirectory: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                           isDirectory.boolValue {
                            DispatchQueue.main.async {
                                viewModel.addFolder(url)
                            }
                        }
                    }
                }
                handled = true
            }
        }

        return handled
    }
}

/// Simple flow layout for folder chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + rowHeight), positions)
    }
}

#Preview {
    FolderSelectionView(viewModel: ScanViewModel())
        .frame(width: 600)
        .padding()
}

#Preview("With Folders") {
    let viewModel = ScanViewModel()
    viewModel.addFolder(URL(fileURLWithPath: "/Users/test/Documents"))
    viewModel.addFolder(URL(fileURLWithPath: "/Users/test/Downloads"))
    viewModel.addFolder(URL(fileURLWithPath: "/Users/test/Desktop"))
    return FolderSelectionView(viewModel: viewModel)
        .frame(width: 600)
        .padding()
}
