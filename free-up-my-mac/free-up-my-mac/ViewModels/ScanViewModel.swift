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

    // MARK: - Services

    private var scannerService: FileScannerService
    private var duplicateDetectorService: DuplicateDetectorService
    private var scanTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        scannerService: FileScannerService = FileScannerService(),
        duplicateDetectorService: DuplicateDetectorService = DuplicateDetectorService()
    ) {
        self.scannerService = scannerService
        self.duplicateDetectorService = duplicateDetectorService
    }

    // MARK: - Computed Properties

    var canStartScan: Bool {
        !selectedFolders.isEmpty && appState != .scanning
    }

    var selectedFilesCount: Int {
        selectedFileIds.count
    }

    var totalPotentialSavings: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.potentialSavings }
    }

    var selectedSavings: Int64 {
        var total: Int64 = 0
        for group in duplicateGroups {
            for file in group.files where selectedFileIds.contains(file.id) {
                total += file.size
            }
        }
        return total
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
        appState = .scanning
        scanProgress = ScanProgress(phase: .enumerating, startTime: Date())

        // Create new scanner service for this scan
        scannerService = FileScannerService()

        do {
            var allFiles: [ScannedFile] = []

            for folder in selectedFolders {
                let files = try await scannerService.scanDirectory(at: folder) { [weak self] progress in
                    Task { @MainActor in
                        self?.scanProgress = progress
                    }
                }
                allFiles.append(contentsOf: files)
            }

            scannedFiles = allFiles

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
        scanProgress = .idle
    }

    // MARK: - Actions

    func trashSelectedFiles() async -> Bool {
        // Stub - will be implemented when FileOperationService is complete
        // For now, just remove from UI
        guard !selectedFileIds.isEmpty else { return false }

        // Remove selected files from duplicate groups
        for i in duplicateGroups.indices {
            duplicateGroups[i].files.removeAll { selectedFileIds.contains($0.id) }
        }

        // Remove empty groups
        duplicateGroups.removeAll { $0.files.count < 2 }

        // Clear selection
        selectedFileIds.removeAll()

        return true
    }

    func revealInFinder(_ file: ScannedFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func openFile(_ file: ScannedFile) {
        NSWorkspace.shared.open(file.url)
    }
}
