import SwiftUI
import QuickLookUI

/// Individual file row with checkbox, icon, and file info
struct FileRowView: View {
    let file: ScannedFile
    let isSelected: Bool
    let isOriginal: Bool
    let onToggle: () -> Void
    let onReveal: () -> Void
    let onQuickLook: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button {
                onToggle()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(isOriginal)
            .opacity(isOriginal ? 0.3 : 1)

            // File icon
            FileIconView(fileExtension: file.fileExtension)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(file.fileName)
                        .fontWeight(isOriginal ? .semibold : .regular)

                    if isOriginal {
                        Text("Original")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }

                Text(file.directoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // File size
            Text(ByteFormatter.format(file.size))
                .foregroundStyle(.secondary)
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
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// File icon based on extension
struct FileIconView: View {
    let fileExtension: String

    var body: some View {
        Image(systemName: iconName)
            .font(.title2)
            .foregroundStyle(iconColor)
            .frame(width: 32, height: 32)
    }

    private var iconName: String {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp", "webp":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "tablecells"
        case "ppt", "pptx":
            return "rectangle.on.rectangle"
        case "mp3", "wav", "aac", "m4a", "flac":
            return "music.note"
        case "mp4", "mov", "avi", "mkv", "m4v":
            return "film"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox"
        case "swift", "py", "js", "ts", "java", "cpp", "c", "h":
            return "chevron.left.forwardslash.chevron.right"
        case "txt", "md", "rtf":
            return "doc.plaintext"
        default:
            return "doc"
        }
    }

    private var iconColor: Color {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp", "webp":
            return .purple
        case "pdf":
            return .red
        case "doc", "docx":
            return .blue
        case "xls", "xlsx":
            return .green
        case "ppt", "pptx":
            return .orange
        case "mp3", "wav", "aac", "m4a", "flac":
            return .pink
        case "mp4", "mov", "avi", "mkv", "m4v":
            return .indigo
        case "zip", "rar", "7z", "tar", "gz":
            return .brown
        case "swift":
            return .orange
        case "py":
            return .yellow
        case "js", "ts":
            return .yellow
        default:
            return .secondary
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        FileRowView(
            file: ScannedFile(
                url: URL(fileURLWithPath: "/Users/test/Documents/photo.jpg"),
                size: 1024 * 512
            ),
            isSelected: false,
            isOriginal: true,
            onToggle: {},
            onReveal: {},
            onQuickLook: {}
        )

        FileRowView(
            file: ScannedFile(
                url: URL(fileURLWithPath: "/Users/test/Downloads/photo_copy.jpg"),
                size: 1024 * 512
            ),
            isSelected: true,
            isOriginal: false,
            onToggle: {},
            onReveal: {},
            onQuickLook: {}
        )

        FileRowView(
            file: ScannedFile(
                url: URL(fileURLWithPath: "/Users/test/Desktop/photo_backup.jpg"),
                size: 1024 * 512
            ),
            isSelected: false,
            isOriginal: false,
            onToggle: {},
            onReveal: {},
            onQuickLook: {}
        )
    }
    .frame(width: 600)
    .padding()
}
