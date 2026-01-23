import SwiftUI

/// Individual folder chip with remove button
struct FolderChipView: View {
    let folder: URL
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)

            Text(folder.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove folder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
        .help(folder.path)
    }
}

#Preview {
    HStack {
        FolderChipView(folder: URL(fileURLWithPath: "/Users/test/Documents")) {}
        FolderChipView(folder: URL(fileURLWithPath: "/Users/test/Downloads")) {}
    }
    .padding()
}
