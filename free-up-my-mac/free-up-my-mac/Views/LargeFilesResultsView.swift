import SwiftUI

/// Results view for large files scan mode
struct LargeFilesResultsView: View {
    @Bindable var viewModel: ScanViewModel

    @State private var sortOption: LargeFileSortOption = .sizeDesc
    @State private var filterExtension: String?
    @State private var isProcessing = false
    @State private var quickLookFile: ScannedFile?
    @State private var showTrashConfirmation = false
    @State private var showSkippedFiles = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            LargeFilesHeaderView(
                totalFolders: viewModel.totalLargeFileFolders,
                totalFiles: viewModel.totalLargeFiles,
                totalSize: viewModel.totalLargeFilesSize,
                minimumSize: viewModel.minimumFileSize,
                scannedFolders: viewModel.selectedFolders,
                skippedFilesCount: viewModel.skippedFiles.count,
                onShowSkippedFiles: {
                    showSkippedFiles = true
                }
            )

            Divider()

            // Sort and filter bar
            LargeFileSortFilterBar(
                sortOption: $sortOption,
                filterExtension: $filterExtension,
                availableExtensions: availableExtensions,
                onSelectAll: { viewModel.selectAllLargeFiles() },
                onDeselectAll: { viewModel.deselectAll() },
                selectedCount: viewModel.selectedLargeFilesCount,
                totalCount: viewModel.totalLargeFiles
            )

            Divider()

            // Large file groups list
            if sortedAndFilteredGroups.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedAndFilteredGroups) { group in
                            LargeFileGroupView(
                                group: group,
                                selectedFileIds: viewModel.selectedFileIds,
                                sortOption: sortOption,
                                dateRange: viewModel.largeFilesDateRange,
                                onToggleFile: { viewModel.toggleFileSelection($0) },
                                onRevealFile: { viewModel.revealInFinder($0) },
                                onQuickLook: { file in
                                    quickLookFile = file
                                }
                            )
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Action bar
            ActionBar(
                selectedCount: viewModel.selectedLargeFilesCount,
                selectedSize: viewModel.selectedLargeFilesSavings,
                isProcessing: isProcessing,
                onTrash: {
                    showTrashConfirmation = true
                },
                onNewScan: {
                    viewModel.resetToIdle()
                }
            )
        }
        .sheet(item: $quickLookFile) { file in
            QuickLookSheet(url: file.url)
        }
        .alert("Move to Trash", isPresented: $showTrashConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                Task {
                    isProcessing = true
                    _ = await viewModel.trashSelectedFiles()
                    isProcessing = false
                    // Refresh disk usage after trash
                    await viewModel.refreshDiskUsage()
                }
            }
        } message: {
            Text(trashConfirmationMessage)
        }
        .alert("Trash Complete", isPresented: $viewModel.showTrashResult) {
            Button("OK", role: .cancel) {
                viewModel.showTrashResult = false
            }
        } message: {
            if let result = viewModel.lastTrashResult {
                Text(trashResultMessage(for: result))
            }
        }
        .sheet(isPresented: $showSkippedFiles) {
            SkippedFilesSummaryView(skippedFiles: viewModel.skippedFiles)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("No Large Files Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("No files larger than \(ByteFormatter.format(viewModel.minimumFileSize)) were found in the scanned folders.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Start New Scan") {
                viewModel.resetToIdle()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Confirmation Messages

    private var trashConfirmationMessage: String {
        let count = viewModel.selectedLargeFilesCount
        let size = ByteFormatter.format(viewModel.selectedLargeFilesSavings)
        let fileWord = count == 1 ? "file" : "files"
        return "Move \(count) \(fileWord) (\(size)) to Trash? This can be undone from Trash."
    }

    private func trashResultMessage(for result: TrashResult) -> String {
        if result.wasCompleteSuccess {
            let size = ByteFormatter.format(result.bytesFreed)
            let fileWord = result.trashedCount == 1 ? "file" : "files"
            return "Successfully moved \(result.trashedCount) \(fileWord) (\(size)) to Trash."
        } else if result.wasPartialSuccess {
            let size = ByteFormatter.format(result.bytesFreed)
            let trashedWord = result.trashedCount == 1 ? "file" : "files"
            let failedWord = result.failedFiles.count == 1 ? "file" : "files"
            return "Moved \(result.trashedCount) \(trashedWord) (\(size)) to Trash. \(result.failedFiles.count) \(failedWord) failed."
        } else if result.wasCompleteFailure {
            let failedWord = result.failedFiles.count == 1 ? "file" : "files"
            return "Failed to move \(result.failedFiles.count) \(failedWord) to Trash."
        } else {
            return "No files were selected."
        }
    }

    // MARK: - Computed Properties

    private var sortedAndFilteredGroups: [LargeFileGroup] {
        var groups = viewModel.largeFileGroups

        // Apply extension filter
        if let ext = filterExtension {
            groups = groups.compactMap { group in
                let filteredFiles = group.files.filter {
                    $0.fileExtension.lowercased() == ext.lowercased()
                }
                if filteredFiles.isEmpty {
                    return nil
                }
                return LargeFileGroup(
                    id: group.id,
                    folderURL: group.folderURL,
                    files: filteredFiles
                )
            }
        }

        // Groups are already sorted by total size from the service
        // Re-sort if filter changed the totals
        groups.sort { $0.totalSize > $1.totalSize }

        return groups
    }

    private var availableExtensions: [String] {
        let extensions = Set(viewModel.largeFileGroups.flatMap { group in
            group.files.map { $0.fileExtension.lowercased() }
        })
        return extensions.sorted()
    }
}

/// Header view for large files results
struct LargeFilesHeaderView: View {
    let totalFolders: Int
    let totalFiles: Int
    let totalSize: Int64
    let minimumSize: Int64
    let scannedFolders: [URL]
    var skippedFilesCount: Int = 0
    var onShowSkippedFiles: (() -> Void)?

    var body: some View {
        HStack(spacing: 24) {
            // Folders stat
            StatCard(
                title: "Folders",
                value: "\(totalFolders)",
                icon: "folder"
            )

            // Total files stat
            StatCard(
                title: "Large Files",
                value: "\(totalFiles)",
                icon: "doc.fill"
            )

            // Total size
            StatCard(
                title: "Total Size",
                value: ByteFormatter.formatCompact(totalSize),
                icon: "externaldrive.fill",
                valueColor: .orange
            )

            // Minimum size threshold
            VStack(alignment: .leading, spacing: 2) {
                Text(">\(ByteFormatter.format(minimumSize))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Text("Minimum Size")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Skipped files warning (only shown if there are skipped files)
            if skippedFilesCount > 0 {
                Button {
                    onShowSkippedFiles?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(skippedFilesCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)

                            Text("Skipped")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("View skipped files")
            }

            Spacer()

            // Scanned folders summary
            VStack(alignment: .trailing, spacing: 4) {
                Text("Scanned \(scannedFolders.count) folder\(scannedFolders.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let first = scannedFolders.first {
                    Text(first.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

#Preview {
    let viewModel = ScanViewModel()
    viewModel.scanMode = .largeFiles
    viewModel.largeFileGroups = [
        LargeFileGroup(
            folderURL: URL(fileURLWithPath: "/Users/test/Documents"),
            files: [
                ScannedFile(
                    url: URL(fileURLWithPath: "/Users/test/Documents/video.mp4"),
                    size: 500 * 1024 * 1024,
                    modificationDate: Date().addingTimeInterval(-86400 * 30)
                ),
                ScannedFile(
                    url: URL(fileURLWithPath: "/Users/test/Documents/backup.zip"),
                    size: 200 * 1024 * 1024,
                    modificationDate: Date().addingTimeInterval(-86400 * 90)
                )
            ]
        ),
        LargeFileGroup(
            folderURL: URL(fileURLWithPath: "/Users/test/Downloads"),
            files: [
                ScannedFile(
                    url: URL(fileURLWithPath: "/Users/test/Downloads/installer.dmg"),
                    size: 1024 * 1024 * 1024,
                    modificationDate: Date().addingTimeInterval(-86400 * 7)
                )
            ]
        )
    ]
    viewModel.appState = .results

    return LargeFilesResultsView(viewModel: viewModel)
        .frame(width: 900, height: 700)
}

#Preview("Empty Results") {
    let viewModel = ScanViewModel()
    viewModel.scanMode = .largeFiles
    viewModel.appState = .results

    return LargeFilesResultsView(viewModel: viewModel)
        .frame(width: 900, height: 700)
}
