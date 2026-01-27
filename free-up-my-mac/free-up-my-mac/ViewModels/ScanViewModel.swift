import Foundation
import SwiftUI

/// Main view model managing app state, folder selection, scan lifecycle, and file selection
@MainActor
@Observable
final class ScanViewModel {

    // MARK: - App State

    enum AppState: Equatable {
        case idle
        case scanning
        case results
        case error(String)

        static func == (lhs: AppState, rhs: AppState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.scanning, .scanning): return true
            case (.results, .results): return true
            case (.error(let lhsMsg), .error(let rhsMsg)): return lhsMsg == rhsMsg
            default: return false
            }
        }
    }

    // MARK: - Published State

    var appState: AppState = .idle
    var selectedFolders: [URL] = []
    var scanProgress: ScanProgress = .idle
    var duplicateGroups: [DuplicateGroup] = []
    var selectedFileIds: Set<UUID> = []
    var scannedFiles: [ScannedFile] = []
    var skippedFiles: [SkippedFile] = []
    var showSkippedFilesAlert: Bool = false

    // MARK: - Services

    private var scannerService: FileScannerService
    private var duplicateDetectorService: DuplicateDetectorService
    private var fileOperationService: FileOperationService
    private let historyManager: HistoryManager
    private var scanTask: Task<Void, Never>?

    // MARK: - Trash Operation State

    var lastTrashResult: TrashResult?
    var showTrashResult: Bool = false

    // MARK: - Initialization

    init(
        scannerService: FileScannerService = FileScannerService(),
        duplicateDetectorService: DuplicateDetectorService = DuplicateDetectorService(),
        fileOperationService: FileOperationService = FileOperationService(),
        historyManager: HistoryManager = HistoryManager()
    ) {
        self.scannerService = scannerService
        self.duplicateDetectorService = duplicateDetectorService
        self.fileOperationService = fileOperationService
        self.historyManager = historyManager
    }

    // MARK: - Computed Properties

    var canStartScan: Bool {
        !selectedFolders.isEmpty && appState != .scanning
    }

    /// Returns the count of unique URLs in the selection (de-duplicated)
    /// This matches the actual number of files that will be trashed
    var selectedFilesCount: Int {
        selectedFilesDeduplicatedByURL.count
    }

    var totalPotentialSavings: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.potentialSavings }
    }

    /// Returns the total size of unique URLs in the selection (de-duplicated)
    /// This matches the actual bytes that will be freed when trashing
    var selectedSavings: Int64 {
        selectedFilesDeduplicatedByURL.reduce(0) { $0 + $1.size }
    }

    /// Helper to get selected files de-duplicated by URL
    /// (same file path could appear multiple times if user scanned overlapping folders)
    private var selectedFilesDeduplicatedByURL: [ScannedFile] {
        var seenURLs = Set<URL>()
        var uniqueFiles: [ScannedFile] = []
        for group in duplicateGroups {
            for file in group.files where selectedFileIds.contains(file.id) {
                if !seenURLs.contains(file.url) {
                    seenURLs.insert(file.url)
                    uniqueFiles.append(file)
                }
            }
        }
        return uniqueFiles
    }

    var totalDuplicateFiles: Int {
        duplicateGroups.reduce(0) { $0 + $1.files.count }
    }

    var totalDuplicateGroups: Int {
        duplicateGroups.count
    }

    // MARK: - Folder Selection

    func addFolder(_ url: URL) {
        guard !selectedFolders.contains(url) else { return }
        selectedFolders.append(url)
    }

    func removeFolder(_ url: URL) {
        selectedFolders.removeAll { $0 == url }
    }

    func clearFolders() {
        selectedFolders.removeAll()
    }

    // MARK: - File Selection

    func toggleFileSelection(_ fileId: UUID) {
        if selectedFileIds.contains(fileId) {
            selectedFileIds.remove(fileId)
        } else {
            selectedFileIds.insert(fileId)
        }
    }

    func isFileSelected(_ fileId: UUID) -> Bool {
        selectedFileIds.contains(fileId)
    }

    func selectAllDuplicates() {
        // Select all duplicates except the first file in each group (keep original)
        for group in duplicateGroups {
            for file in group.files.dropFirst() {
                selectedFileIds.insert(file.id)
            }
        }
    }

    func deselectAll() {
        selectedFileIds.removeAll()
    }

    // MARK: - Scan Lifecycle

    func startScan() async {
        guard canStartScan else { return }

        // Clear previous results
        scannedFiles.removeAll()
        duplicateGroups.removeAll()
        selectedFileIds.removeAll()
        skippedFiles.removeAll()
        appState = .scanning
        scanProgress = ScanProgress(phase: .enumerating, startTime: Date())

        // Create new services for this scan to ensure fresh cancellation state.
        // Note: This replaces any services injected at init, which is intentional for production use.
        // For testing, consider testing the services directly rather than through the ViewModel.
        scannerService = FileScannerService()

        do {
            var allFiles: [ScannedFile] = []
            var allSkippedFiles: [SkippedFile] = []

            for folder in selectedFolders {
                let result = try await scannerService.scanDirectoryWithSkipped(at: folder) { [weak self] progress in
                    Task { @MainActor in
                        self?.scanProgress = progress
                    }
                }
                allFiles.append(contentsOf: result.files)
                allSkippedFiles.append(contentsOf: result.skippedFiles)
            }

            scannedFiles = allFiles
            skippedFiles = allSkippedFiles

            // Create a new detector service for this scan
            duplicateDetectorService = DuplicateDetectorService()

            // Find duplicates using real content-based detection
            duplicateGroups = try await duplicateDetectorService.findDuplicates(
                in: allFiles
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.scanProgress = progress
                }
            }

            appState = .results

        } catch let error as ScanError {
            switch error {
            case .cancelled:
                appState = .idle
                scanProgress = ScanProgress(phase: .cancelled)
            case .directoryNotFound(let url):
                appState = .error("Directory not found: \(url.path)")
                scanProgress = ScanProgress(phase: .failed, error: "Directory not found")
            case .accessDenied(let url):
                appState = .error("Access denied: \(url.path)")
                scanProgress = ScanProgress(phase: .failed, error: "Access denied")
            }
        } catch let error as HashError {
            switch error {
            case .cancelled:
                appState = .idle
                scanProgress = ScanProgress(phase: .cancelled)
            case .fileNotFound(let url):
                appState = .error("File not found: \(url.path)")
                scanProgress = ScanProgress(phase: .failed, error: "File not found")
            case .readError(let url, let message):
                appState = .error("Error reading \(url.lastPathComponent): \(message)")
                scanProgress = ScanProgress(phase: .failed, error: "Read error")
            }
        } catch {
            appState = .error(error.localizedDescription)
            scanProgress = ScanProgress(phase: .failed, error: error.localizedDescription)
        }
    }

    func cancelScan() {
        Task {
            await scannerService.cancelScan()
            await duplicateDetectorService.cancel()
        }
        appState = .idle
        scanProgress = ScanProgress(phase: .cancelled)
    }

    func resetToIdle() {
        appState = .idle
        duplicateGroups.removeAll()
        selectedFileIds.removeAll()
        scannedFiles.removeAll()
        skippedFiles.removeAll()
        scanProgress = .idle
    }

    // MARK: - Actions

    /// Trash selected files and return result
    func trashSelectedFiles() async -> TrashResult {
        guard !selectedFileIds.isEmpty else {
            return TrashResult(trashedCount: 0, bytesFreed: 0, failedFiles: [])
        }

        // Collect files to trash from selected IDs, de-duplicating by URL
        // (same file path could appear multiple times if user scanned overlapping folders)
        var seenURLs = Set<URL>()
        var filesToTrash: [ScannedFile] = []
        for group in duplicateGroups {
            for file in group.files where selectedFileIds.contains(file.id) {
                if !seenURLs.contains(file.url) {
                    seenURLs.insert(file.url)
                    filesToTrash.append(file)
                }
            }
        }

        guard !filesToTrash.isEmpty else {
            return TrashResult(trashedCount: 0, bytesFreed: 0, failedFiles: [])
        }

        var trashedCount = 0
        var bytesFreed: Int64 = 0
        var failedFiles: [FailedFile] = []

        do {
            bytesFreed = try await fileOperationService.moveToTrash(filesToTrash)
            trashedCount = filesToTrash.count
        } catch let error as FileOperationError {
            switch error {
            case .partialFailure(let count, let bytes, let errors):
                trashedCount = count
                bytesFreed = bytes
                failedFiles = errors.map { convertToFailedFile($0) }
            // Note: The cases below are defensive handling. Currently, the batch
            // moveToTrash(_:) always wraps errors in partialFailure. These cases
            // handle potential future API changes or direct single-file operations.
            // When a single-file error occurs, no files were successfully trashed,
            // so we treat all files as failed to prevent incorrect UI removal.
            case .fileNotFound(let url):
                failedFiles = filesToTrash.map {
                    FailedFile(url: $0.url, reason: $0.url == url ? .notFound : .unknown("Operation aborted"))
                }
            case .permissionDenied(let url):
                failedFiles = filesToTrash.map {
                    FailedFile(url: $0.url, reason: $0.url == url ? .permissionDenied : .unknown("Operation aborted"))
                }
            case .trashFailed(let url, let underlyingError):
                failedFiles = filesToTrash.map {
                    FailedFile(url: $0.url, reason: $0.url == url ? .unknown(underlyingError.localizedDescription) : .unknown("Operation aborted"))
                }
            case .deletionFailed(let url, let underlyingError):
                failedFiles = filesToTrash.map {
                    FailedFile(url: $0.url, reason: $0.url == url ? .unknown(underlyingError.localizedDescription) : .unknown("Operation aborted"))
                }
            }
        } catch {
            // Unexpected error - treat all files as failed
            failedFiles = filesToTrash.map {
                FailedFile(url: $0.url, reason: .unknown(error.localizedDescription))
            }
        }

        // Update UI - remove successfully trashed files from groups
        // Filter by URL (not ID) to handle cases where the same file appears
        // multiple times with different IDs from overlapping folder scans
        let failedURLs = Set(failedFiles.map { $0.url })
        let trashedURLs = Set(filesToTrash.filter { !failedURLs.contains($0.url) }.map { $0.url })

        for i in duplicateGroups.indices {
            duplicateGroups[i].files.removeAll { trashedURLs.contains($0.url) }
        }

        // Remove groups with fewer than 2 files (no longer duplicates)
        duplicateGroups.removeAll { $0.files.count < 2 }

        // Clear selection
        selectedFileIds.removeAll()

        let result = TrashResult(
            trashedCount: trashedCount,
            bytesFreed: bytesFreed,
            failedFiles: failedFiles
        )

        lastTrashResult = result
        showTrashResult = true

        // Record cleanup session to history if any files were trashed
        if trashedCount > 0 {
            await recordCleanupSession(result: result)
        }

        return result
    }

    /// Record a cleanup session to history
    private func recordCleanupSession(result: TrashResult) async {
        let session = CleanupSession(
            scannedDirectories: selectedFolders.map { $0.path },
            filesDeleted: result.trashedCount,
            bytesRecovered: result.bytesFreed,
            duplicateGroupsCleaned: 0, // Could track affected groups if needed
            errors: result.failedFiles.map { $0.reason.localizedDescription }
        )

        do {
            try await historyManager.saveSession(session)
        } catch {
            // Log but don't fail the trash operation
            print("Failed to record cleanup session: \(error)")
        }
    }

    /// Convert FileOperationError to FailedFile
    private func convertToFailedFile(_ error: FileOperationError) -> FailedFile {
        switch error {
        case .fileNotFound(let url):
            return FailedFile(url: url, reason: .notFound)
        case .permissionDenied(let url):
            return FailedFile(url: url, reason: .permissionDenied)
        case .trashFailed(let url, let underlyingError):
            return FailedFile(url: url, reason: .unknown(underlyingError.localizedDescription))
        case .deletionFailed(let url, let underlyingError):
            return FailedFile(url: url, reason: .unknown(underlyingError.localizedDescription))
        case .partialFailure:
            // This shouldn't happen in this context
            return FailedFile(url: URL(fileURLWithPath: "/"), reason: .unknown("Partial failure"))
        }
    }

    func revealInFinder(_ file: ScannedFile) {
        guard FileManager.default.fileExists(atPath: file.url.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func openFile(_ file: ScannedFile) {
        guard FileManager.default.fileExists(atPath: file.url.path) else { return }
        NSWorkspace.shared.open(file.url)
    }
}
