import SwiftUI

/// View showing scan progress with progress bar, stats, and cancel button
struct ScanProgressView: View {
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Scanning indicator
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.bottom, 8)

                Text("Scanning for Duplicates")
                    .font(.title)
                    .fontWeight(.semibold)

                Text(phaseDescription)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: viewModel.scanProgress.fileProgress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 400)

                HStack {
                    Text("\(viewModel.scanProgress.processedFiles) files scanned")
                    Spacer()
                    if viewModel.scanProgress.bytesProcessed > 0 {
                        Text(ByteFormatter.format(viewModel.scanProgress.bytesProcessed))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)
            }

            // Current file being processed
            if let currentFile = viewModel.scanProgress.currentFile {
                Text(truncatedPath(currentFile))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 500)
            }

            // Elapsed time
            if let elapsed = viewModel.scanProgress.elapsedTime {
                Text("Elapsed: \(formatDuration(elapsed))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Cancel button
            Button("Cancel Scan", role: .cancel) {
                viewModel.cancelScan()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()
        }
        .padding(32)
    }

    private var phaseDescription: String {
        viewModel.scanProgress.phase.rawValue
    }

    private func truncatedPath(_ path: String) -> String {
        let maxLength = 60
        if path.count <= maxLength {
            return path
        }
        let start = path.prefix(20)
        let end = path.suffix(35)
        return "\(start)...\(end)"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

#Preview {
    let viewModel = ScanViewModel()
    // Simulate scanning state
    viewModel.appState = .scanning
    return ScanProgressView(viewModel: viewModel)
        .frame(width: 800, height: 600)
}

#Preview("With Progress") {
    let viewModel = ScanViewModel()
    viewModel.appState = .scanning
    viewModel.scanProgress = ScanProgress(
        phase: .enumerating,
        totalFiles: 1000,
        processedFiles: 350,
        currentFile: "/Users/test/Documents/Projects/MyApp/src/components/very/deep/nested/file.swift",
        bytesProcessed: 1024 * 1024 * 50,
        startTime: Date().addingTimeInterval(-45)
    )
    return ScanProgressView(viewModel: viewModel)
        .frame(width: 800, height: 600)
}
