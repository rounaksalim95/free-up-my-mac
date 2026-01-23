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
                Text(session.scannedDirectory)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

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

#Preview {
    VStack(spacing: 8) {
        SessionRowView(
            session: CleanupSession(
                date: Date().addingTimeInterval(-3600),
                scannedDirectory: "/Users/test/Documents",
                filesDeleted: 23,
                bytesRecovered: 1024 * 1024 * 150,
                duplicateGroupsCleaned: 8
            ),
            onDelete: {}
        )

        SessionRowView(
            session: CleanupSession(
                date: Date().addingTimeInterval(-86400 * 2),
                scannedDirectory: "/Users/test/Downloads/Very Long Directory Name That Should Truncate",
                filesDeleted: 5,
                bytesRecovered: 1024 * 1024 * 25,
                duplicateGroupsCleaned: 2,
                errors: ["Some error occurred"]
            ),
            onDelete: {}
        )
    }
    .frame(width: 500)
    .padding()
}
