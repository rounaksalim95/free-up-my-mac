import SwiftUI

/// Expandable folder group showing large files within it
struct LargeFileGroupView: View {
    let group: LargeFileGroup
    let selectedFileIds: Set<UUID>
    let sortOption: LargeFileSortOption
    let dateRange: (oldest: Date, newest: Date)?
    let onToggleFile: (UUID) -> Void
    let onRevealFile: (ScannedFile) -> Void
    let onQuickLook: (ScannedFile) -> Void

    @State private var isExpanded = true

    private var sortedFiles: [ScannedFile] {
        group.filesSorted(by: sortOption, dateRange: dateRange)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)

                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.folderName)
                            .fontWeight(.medium)

                        Text(group.folderPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    // Size and count badge
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ByteFormatter.format(group.totalSize))
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)

                        Text("\(group.fileCount) \(group.fileCount == 1 ? "file" : "files")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // File list with transition
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(sortedFiles.enumerated()), id: \.element.id) { index, file in
                        LargeFileRowView(
                            file: file,
                            isSelected: selectedFileIds.contains(file.id),
                            onToggle: { onToggleFile(file.id) },
                            onReveal: { onRevealFile(file) },
                            onQuickLook: { onQuickLook(file) }
                        )
                        .padding(.leading, 32)

                        if index < sortedFiles.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
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

/// Individual file row for large files (without "Original" badge)
struct LargeFileRowView: View {
    let file: ScannedFile
    let isSelected: Bool
    let onToggle: () -> Void
    let onReveal: () -> Void
    let onQuickLook: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox with animation
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    onToggle()
                }
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .scaleEffect(isSelected ? 1.0 : 0.95)
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)

            // File icon
            FileIconView(fileExtension: file.fileExtension)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)

                HStack(spacing: 8) {
                    if let date = file.modificationDate {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // File size
            Text(ByteFormatter.format(file.size))
                .foregroundStyle(.orange)
                .fontWeight(.medium)
                .monospacedDigit()

            // Action buttons (visible on hover)
            HStack(spacing: 8) {
                Button {
                    onQuickLook()
                } label: {
                    Image(systemName: "eye")
                }
                .buttonStyle(.plain)
                .help("Quick Look")

                Button {
                    onReveal()
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
            .foregroundStyle(.secondary)
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    let file1 = ScannedFile(
        url: URL(fileURLWithPath: "/Users/test/Documents/large_video.mp4"),
        size: 1024 * 1024 * 500,
        modificationDate: Date().addingTimeInterval(-86400 * 30)
    )
    let file2 = ScannedFile(
        url: URL(fileURLWithPath: "/Users/test/Documents/project_backup.zip"),
        size: 1024 * 1024 * 200,
        modificationDate: Date().addingTimeInterval(-86400 * 90)
    )
    let file3 = ScannedFile(
        url: URL(fileURLWithPath: "/Users/test/Documents/photo_collection.zip"),
        size: 1024 * 1024 * 150,
        modificationDate: Date().addingTimeInterval(-86400 * 7)
    )

    let group = LargeFileGroup(
        folderURL: URL(fileURLWithPath: "/Users/test/Documents"),
        files: [file1, file2, file3]
    )

    return LargeFileGroupView(
        group: group,
        selectedFileIds: [file2.id],
        sortOption: .sizeDesc,
        dateRange: nil,
        onToggleFile: { _ in },
        onRevealFile: { _ in },
        onQuickLook: { _ in }
    )
    .frame(width: 600)
    .padding()
}
