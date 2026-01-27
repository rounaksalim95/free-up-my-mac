import SwiftUI

/// Sheet showing list of skipped files with reasons
struct SkippedFilesSummaryView: View {
    let skippedFiles: [SkippedFile]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skipped Files")
                        .font(.headline)
                    Text("\(skippedFiles.count) file\(skippedFiles.count == 1 ? " was" : "s were") skipped during scan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // File list
            if skippedFiles.isEmpty {
                ContentUnavailableView(
                    "No Skipped Files",
                    systemImage: "checkmark.circle",
                    description: Text("All files were scanned successfully.")
                )
            } else {
                List(skippedFiles) { file in
                    SkippedFileRow(file: file)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

/// Individual row for a skipped file
struct SkippedFileRow: View {
    let file: SkippedFile

    var body: some View {
        HStack(spacing: 12) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .fontWeight(.medium)

                Text(file.directoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // Reason badge
                Text(file.reason.localizedDescription)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(reasonColor.opacity(0.2))
                    .foregroundStyle(reasonColor)
                    .clipShape(Capsule())
            }

            Spacer()

            // Reveal in Finder button
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([file.url.deletingLastPathComponent()])
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Reveal in Finder")
        }
        .padding(.vertical, 4)
    }

    private var reasonColor: Color {
        switch file.reason {
        case .permissionDenied:
            return .red
        case .readError:
            return .orange
        case .hashingFailed:
            return .purple
        }
    }
}

#Preview("With Skipped Files") {
    SkippedFilesSummaryView(skippedFiles: [
        SkippedFile(
            url: URL(fileURLWithPath: "/Users/test/Documents/protected.pdf"),
            reason: .permissionDenied
        ),
        SkippedFile(
            url: URL(fileURLWithPath: "/Users/test/Downloads/corrupted.zip"),
            reason: .readError("Unable to read file contents")
        ),
        SkippedFile(
            url: URL(fileURLWithPath: "/Users/test/Desktop/large.bin"),
            reason: .hashingFailed("Timeout during hashing")
        )
    ])
}

#Preview("Empty") {
    SkippedFilesSummaryView(skippedFiles: [])
}
