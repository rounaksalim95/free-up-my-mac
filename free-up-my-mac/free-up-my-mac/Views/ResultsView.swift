import SwiftUI

/// Container view for results with header, list, and action bar
struct ResultsView: View {
    @Bindable var viewModel: ScanViewModel

    @State private var sortOption: SortOption = .savingsDesc
    @State private var filterExtension: String?
    @State private var isProcessing = false
    @State private var quickLookFile: ScannedFile?
    @State private var showTrashConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            ResultsHeaderView(
                totalGroups: viewModel.totalDuplicateGroups,
                totalFiles: viewModel.totalDuplicateFiles,
                potentialSavings: viewModel.totalPotentialSavings,
                scannedFolders: viewModel.selectedFolders
            )

            Divider()

            // Sort and filter bar
            SortFilterBar(
                sortOption: $sortOption,
                filterExtension: $filterExtension,
                availableExtensions: availableExtensions,
                onSelectAll: { viewModel.selectAllDuplicates() },
                onDeselectAll: { viewModel.deselectAll() },
                selectedCount: viewModel.selectedFilesCount,
                totalCount: viewModel.totalDuplicateFiles
            )

            Divider()

            // Duplicate groups list
            DuplicateGroupList(
                groups: sortedAndFilteredGroups,
                selectedFileIds: viewModel.selectedFileIds,
                onToggleFile: { viewModel.toggleFileSelection($0) },
                onRevealFile: { viewModel.revealInFinder($0) },
                onQuickLook: { file in
                    quickLookFile = file
                }
            )

            Divider()

            // Action bar
            ActionBar(
                selectedCount: viewModel.selectedFilesCount,
                selectedSize: viewModel.selectedSavings,
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
    }

    // MARK: - Confirmation Messages

    private var trashConfirmationMessage: String {
        let count = viewModel.selectedFilesCount
        let size = ByteFormatter.format(viewModel.selectedSavings)
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

    private var sortedAndFilteredGroups: [DuplicateGroup] {
        var groups = viewModel.duplicateGroups

        // Apply filter
        if let ext = filterExtension {
            groups = groups.filter { $0.fileExtension.lowercased() == ext.lowercased() }
        }

        // Apply sort
        switch sortOption {
        case .savingsDesc:
            groups.sort { $0.potentialSavings > $1.potentialSavings }
        case .savingsAsc:
            groups.sort { $0.potentialSavings < $1.potentialSavings }
        case .sizeDesc:
            groups.sort { $0.size > $1.size }
        case .sizeAsc:
            groups.sort { $0.size < $1.size }
        case .countDesc:
            groups.sort { $0.duplicateCount > $1.duplicateCount }
        case .countAsc:
            groups.sort { $0.duplicateCount < $1.duplicateCount }
        }

        return groups
    }

    private var availableExtensions: [String] {
        let extensions = Set(viewModel.duplicateGroups.map { $0.fileExtension.lowercased() })
        return extensions.sorted()
    }
}

#Preview {
    let viewModel = ScanViewModel()
    viewModel.duplicateGroups = MockDataProvider.generatePreviewDuplicates(count: 5)
    viewModel.appState = .results

    return ResultsView(viewModel: viewModel)
        .frame(width: 900, height: 700)
}

#Preview("Empty Results") {
    let viewModel = ScanViewModel()
    viewModel.appState = .results

    return ResultsView(viewModel: viewModel)
        .frame(width: 900, height: 700)
}
