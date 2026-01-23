import SwiftUI

/// Single duplicate group with expandable file list
struct DuplicateGroupView: View {
    let group: DuplicateGroup
    let selectedFileIds: Set<UUID>
    let onToggleFile: (UUID) -> Void
    let onRevealFile: (ScannedFile) -> Void
    let onQuickLook: (ScannedFile) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    FileIconView(fileExtension: group.fileExtension)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.fileName)
                            .fontWeight(.medium)

                        Text("\(group.duplicateCount) files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Potential savings badge
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ByteFormatter.format(group.potentialSavings))
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)

                        Text("potential savings")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // File list
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(group.files.enumerated()), id: \.element.id) { index, file in
                        FileRowView(
                            file: file,
                            isSelected: selectedFileIds.contains(file.id),
                            isOriginal: index == 0,
                            onToggle: { onToggleFile(file.id) },
                            onReveal: { onRevealFile(file) },
                            onQuickLook: { onQuickLook(file) }
                        )
                        .padding(.leading, 32)

                        if index < group.files.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var selectedCount: Int {
        group.files.filter { selectedFileIds.contains($0.id) }.count
    }
}

#Preview {
    let file1 = ScannedFile(
        url: URL(fileURLWithPath: "/Users/test/Documents/photo.jpg"),
        size: 1024 * 512
    )
    let file2 = ScannedFile(
        url: URL(fileURLWithPath: "/Users/test/Downloads/photo_copy.jpg"),
        size: 1024 * 512
    )
    let file3 = ScannedFile(
        url: URL(fileURLWithPath: "/Users/test/Desktop/photo_backup.jpg"),
        size: 1024 * 512
    )

    let group = DuplicateGroup(
        hash: "abc123",
        size: 1024 * 512,
        files: [file1, file2, file3]
    )

    return DuplicateGroupView(
        group: group,
        selectedFileIds: [file2.id],
        onToggleFile: { _ in },
        onRevealFile: { _ in },
        onQuickLook: { _ in }
    )
    .frame(width: 600)
    .padding()
}
