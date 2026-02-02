import SwiftUI

/// Single cleanup session row in history list
struct SessionRowView: View {
    let session: CleanupSession
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            Image(systemName: session.wasSuccessful ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.title2)
                .foregroundStyle(session.wasSuccessful ? .green : .orange)

            // Session info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(session.scannedDirectory)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    // Cleanup type badge
                    CleanupTypeBadge(type: session.cleanupType)
                }

                HStack(spacing: 12) {
                    Label("\(session.filesDeleted) files", systemImage: "doc.on.doc")
                    Label(ByteFormatter.format(session.bytesRecovered), systemImage: "arrow.down.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Date
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatRelativeDate(session.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formatAbsoluteDate(session.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Delete button (visible on hover)
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .help("Delete this session from history")
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatAbsoluteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Badge showing the cleanup type
struct CleanupTypeBadge: View {
    let type: CleanupType

    var body: some View {
        Label(type.displayName, systemImage: type.iconName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch type {
        case .duplicates:
            return Color.blue.opacity(0.2)
        case .largeFiles:
            return Color.orange.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch type {
        case .duplicates:
            return .blue
        case .largeFiles:
            return .orange
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        SessionRowView(
            session: CleanupSession(
                date: Date().addingTimeInterval(-3600),
                scannedDirectory: "/Users/test/Documents",
                filesDeleted: 23,
                bytesRecovered: 1024 * 1024 * 150,
                duplicateGroupsCleaned: 8,
                cleanupType: .duplicates
            ),
            onDelete: {}
        )

        SessionRowView(
            session: CleanupSession(
                date: Date().addingTimeInterval(-86400 * 2),
                scannedDirectory: "/Users/test/Downloads/Very Long Directory Name That Should Truncate",
                filesDeleted: 5,
                bytesRecovered: 1024 * 1024 * 250,
                duplicateGroupsCleaned: 0,
                cleanupType: .largeFiles
            ),
            onDelete: {}
        )

        SessionRowView(
            session: CleanupSession(
                date: Date().addingTimeInterval(-86400 * 5),
                scannedDirectory: "/Users/test/Pictures",
                filesDeleted: 3,
                bytesRecovered: 1024 * 1024 * 25,
                duplicateGroupsCleaned: 2,
                errors: ["Some error occurred"]
            ),
            onDelete: {}
        )
    }
    .frame(width: 600)
    .padding()
}
