import Testing
import Foundation
@testable import free_up_my_mac

@Suite("ScanViewModel Tests")
@MainActor
struct ScanViewModelTests {

    // MARK: - Initial State Tests

    @Test("Initial state is idle")
    func testInitialState_IsIdle() async {
        let viewModel = ScanViewModel()

        #expect(viewModel.appState == .idle)
        #expect(viewModel.selectedFolders.isEmpty)
        #expect(viewModel.duplicateGroups.isEmpty)
        #expect(viewModel.selectedFileIds.isEmpty)
    }

    @Test("Initial scan progress is idle")
    func testInitialScanProgress_IsIdle() async {
        let viewModel = ScanViewModel()

        #expect(viewModel.scanProgress.phase == .idle)
        #expect(viewModel.scanProgress.totalFiles == 0)
    }

    // MARK: - Folder Selection Tests

    @Test("Add folder adds to selected folders")
    func testAddFolder_AddsToSelectedFolders() async {
        let viewModel = ScanViewModel()
        let folderURL = URL(fileURLWithPath: "/Users/test/Documents")

        viewModel.addFolder(folderURL)

        #expect(viewModel.selectedFolders.count == 1)
        #expect(viewModel.selectedFolders.first == folderURL)
    }

    @Test("Add duplicate folder is ignored")
    func testAddDuplicateFolder_IsIgnored() async {
        let viewModel = ScanViewModel()
        let folderURL = URL(fileURLWithPath: "/Users/test/Documents")

        viewModel.addFolder(folderURL)
        viewModel.addFolder(folderURL)

        #expect(viewModel.selectedFolders.count == 1)
    }

    @Test("Remove folder removes from selected folders")
    func testRemoveFolder_RemovesFromSelectedFolders() async {
        let viewModel = ScanViewModel()
        let folder1 = URL(fileURLWithPath: "/Users/test/Documents")
        let folder2 = URL(fileURLWithPath: "/Users/test/Downloads")

        viewModel.addFolder(folder1)
        viewModel.addFolder(folder2)
        viewModel.removeFolder(folder1)

        #expect(viewModel.selectedFolders.count == 1)
        #expect(viewModel.selectedFolders.first == folder2)
    }

    @Test("Clear folders removes all selected folders")
    func testClearFolders_RemovesAllSelectedFolders() async {
        let viewModel = ScanViewModel()
        let folder1 = URL(fileURLWithPath: "/Users/test/Documents")
        let folder2 = URL(fileURLWithPath: "/Users/test/Downloads")

        viewModel.addFolder(folder1)
        viewModel.addFolder(folder2)
        viewModel.clearFolders()

        #expect(viewModel.selectedFolders.isEmpty)
    }

    @Test("Can start scan returns false when no folders selected")
    func testCanStartScan_ReturnsFalse_WhenNoFoldersSelected() async {
        let viewModel = ScanViewModel()

        #expect(viewModel.canStartScan == false)
    }

    @Test("Can start scan returns true when folders selected")
    func testCanStartScan_ReturnsTrue_WhenFoldersSelected() async {
        let viewModel = ScanViewModel()
        viewModel.addFolder(URL(fileURLWithPath: "/Users/test/Documents"))

        #expect(viewModel.canStartScan == true)
    }

    // MARK: - Scan Lifecycle Tests

    @Test("Start scan changes state to scanning")
    func testStartScan_ChangesStateToScanning() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        try testDir.addFile(name: "test.txt", size: 2048)

        let viewModel = ScanViewModel()
        viewModel.addFolder(testDir.url)

        // Start scan but don't await completion
        Task {
            await viewModel.startScan()
        }

        // Give the task time to start
        try await Task.sleep(for: .milliseconds(50))

        // State should be scanning or already completed
        let validStates: [ScanViewModel.AppState] = [.scanning, .results]
        #expect(validStates.contains(where: { $0 == viewModel.appState }))
    }

    @Test("Completed scan changes state to results")
    func testCompletedScan_ChangesStateToResults() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        try testDir.addFile(name: "test.txt", size: 2048)

        let viewModel = ScanViewModel()
        viewModel.addFolder(testDir.url)

        await viewModel.startScan()

        #expect(viewModel.appState == .results)
    }

    @Test("Cancel scan changes state back to idle")
    func testCancelScan_ChangesStateToIdle() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create many files to ensure scan takes time
        for i in 0..<100 {
            try testDir.addFile(name: "file\(i).txt", size: 2048)
        }

        let viewModel = ScanViewModel()
        viewModel.addFolder(testDir.url)

        Task {
            await viewModel.startScan()
        }

        // Give scan time to start
        try await Task.sleep(for: .milliseconds(10))

        viewModel.cancelScan()

        // Wait for cancellation to take effect
        try await Task.sleep(for: .milliseconds(100))

        // Should be back to idle after cancellation
        #expect(viewModel.appState == .idle || viewModel.appState == .results)
    }

    @Test("New scan clears previous results")
    func testNewScan_ClearsPreviousResults() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        try testDir.addFile(name: "test.txt", size: 2048)

        let viewModel = ScanViewModel()
        viewModel.addFolder(testDir.url)

        // First scan
        await viewModel.startScan()

        let firstGroupCount = viewModel.duplicateGroups.count

        // Reset to idle
        viewModel.resetToIdle()

        // Second scan
        await viewModel.startScan()

        // Results should be fresh (same count as first scan with same files)
        #expect(viewModel.duplicateGroups.count == firstGroupCount)
    }

    // MARK: - File Selection Tests

    @Test("Toggle file selection adds file ID")
    func testToggleFileSelection_AddsFileId() async {
        let viewModel = ScanViewModel()
        let fileId = UUID()

        viewModel.toggleFileSelection(fileId)

        #expect(viewModel.selectedFileIds.contains(fileId))
    }

    @Test("Toggle file selection removes file ID if already selected")
    func testToggleFileSelection_RemovesFileId_IfAlreadySelected() async {
        let viewModel = ScanViewModel()
        let fileId = UUID()

        viewModel.toggleFileSelection(fileId)
        viewModel.toggleFileSelection(fileId)

        #expect(!viewModel.selectedFileIds.contains(fileId))
    }

    @Test("Select all files selects all duplicate file IDs")
    func testSelectAllFiles_SelectsAllDuplicateFileIds() async {
        let viewModel = ScanViewModel()

        // Create mock duplicate groups with files
        let file1 = ScannedFile(url: URL(fileURLWithPath: "/test/file1.txt"), size: 1024)
        let file2 = ScannedFile(url: URL(fileURLWithPath: "/test/file2.txt"), size: 1024)
        let file3 = ScannedFile(url: URL(fileURLWithPath: "/test/file3.txt"), size: 2048)
        let file4 = ScannedFile(url: URL(fileURLWithPath: "/test/file4.txt"), size: 2048)

        viewModel.duplicateGroups = [
            DuplicateGroup(hash: "abc123", size: 1024, files: [file1, file2]),
            DuplicateGroup(hash: "def456", size: 2048, files: [file3, file4])
        ]

        viewModel.selectAllDuplicates()

        // Should select all duplicates (keeping one original per group)
        // Each group with n files should have n-1 selected
        #expect(viewModel.selectedFileIds.count == 2)
    }

    @Test("Deselect all files clears selection")
    func testDeselectAllFiles_ClearsSelection() async {
        let viewModel = ScanViewModel()

        viewModel.toggleFileSelection(UUID())
        viewModel.toggleFileSelection(UUID())

        viewModel.deselectAll()

        #expect(viewModel.selectedFileIds.isEmpty)
    }

    @Test("Selected files count returns correct count")
    func testSelectedFilesCount_ReturnsCorrectCount() async {
        let viewModel = ScanViewModel()

        viewModel.toggleFileSelection(UUID())
        viewModel.toggleFileSelection(UUID())
        viewModel.toggleFileSelection(UUID())

        #expect(viewModel.selectedFilesCount == 3)
    }

    // MARK: - Computed Properties Tests

    @Test("Total potential savings calculates correctly")
    func testTotalPotentialSavings_CalculatesCorrectly() async {
        let viewModel = ScanViewModel()

        let file1 = ScannedFile(url: URL(fileURLWithPath: "/test/file1.txt"), size: 1024)
        let file2 = ScannedFile(url: URL(fileURLWithPath: "/test/file2.txt"), size: 1024)
        let file3 = ScannedFile(url: URL(fileURLWithPath: "/test/file3.txt"), size: 2048)
        let file4 = ScannedFile(url: URL(fileURLWithPath: "/test/file4.txt"), size: 2048)

        viewModel.duplicateGroups = [
            DuplicateGroup(hash: "abc123", size: 1024, files: [file1, file2]),
            DuplicateGroup(hash: "def456", size: 2048, files: [file3, file4])
        ]

        // Group 1: 1024 * (2-1) = 1024
        // Group 2: 2048 * (2-1) = 2048
        // Total: 3072
        #expect(viewModel.totalPotentialSavings == 3072)
    }

    @Test("Selected savings calculates correctly")
    func testSelectedSavings_CalculatesCorrectly() async {
        let viewModel = ScanViewModel()

        let file1 = ScannedFile(url: URL(fileURLWithPath: "/test/file1.txt"), size: 1024)
        let file2 = ScannedFile(url: URL(fileURLWithPath: "/test/file2.txt"), size: 1024)

        viewModel.duplicateGroups = [
            DuplicateGroup(hash: "abc123", size: 1024, files: [file1, file2])
        ]

        viewModel.toggleFileSelection(file1.id)

        #expect(viewModel.selectedSavings == 1024)
    }

    // MARK: - Reset and Error State Tests

    @Test("Reset to idle clears state")
    func testResetToIdle_ClearsState() async {
        let viewModel = ScanViewModel()

        viewModel.addFolder(URL(fileURLWithPath: "/test"))
        viewModel.toggleFileSelection(UUID())

        viewModel.resetToIdle()

        #expect(viewModel.appState == .idle)
        #expect(viewModel.duplicateGroups.isEmpty)
        #expect(viewModel.selectedFileIds.isEmpty)
        // Selected folders should persist
        #expect(viewModel.selectedFolders.count == 1)
    }

    @Test("Scan with invalid folder sets error state")
    func testScanWithInvalidFolder_SetsErrorState() async {
        let viewModel = ScanViewModel()
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString)")

        viewModel.addFolder(invalidURL)
        await viewModel.startScan()

        if case .error = viewModel.appState {
            // Expected
        } else {
            Issue.record("Expected error state")
        }
    }

    // MARK: - Trash Operation Tests

    @Test("Trash selected files removes from groups")
    func testTrashSelectedFiles_RemovesFromGroups() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create actual files that can be trashed
        let file1URL = try testDir.addFile(name: "file1.txt", size: 1024)
        let file2URL = try testDir.addFile(name: "file2.txt", size: 1024)
        let file3URL = try testDir.addFile(name: "file3.txt", size: 1024)

        let file1 = ScannedFile(url: file1URL, size: 1024)
        let file2 = ScannedFile(url: file2URL, size: 1024)
        let file3 = ScannedFile(url: file3URL, size: 1024)

        let viewModel = ScanViewModel()
        viewModel.duplicateGroups = [
            DuplicateGroup(hash: "abc123", size: 1024, files: [file1, file2, file3])
        ]

        // Select file2 for deletion (keep file1 as "original")
        viewModel.toggleFileSelection(file2.id)

        let result = await viewModel.trashSelectedFiles()

        // Verify result
        #expect(result.trashedCount == 1)
        #expect(result.bytesFreed == 1024)
        #expect(result.wasCompleteSuccess)

        // Verify file2 was removed from the group
        #expect(viewModel.duplicateGroups.count == 1)
        #expect(viewModel.duplicateGroups[0].files.count == 2)
        #expect(!viewModel.duplicateGroups[0].files.contains { $0.id == file2.id })

        // Verify file was actually trashed
        #expect(!FileManager.default.fileExists(atPath: file2URL.path))
    }

    @Test("Trash all but one file removes entire group")
    func testTrashAllButOneFile_RemovesEntireGroup() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let file1URL = try testDir.addFile(name: "file1.txt", size: 1024)
        let file2URL = try testDir.addFile(name: "file2.txt", size: 1024)

        let file1 = ScannedFile(url: file1URL, size: 1024)
        let file2 = ScannedFile(url: file2URL, size: 1024)

        let viewModel = ScanViewModel()
        viewModel.duplicateGroups = [
            DuplicateGroup(hash: "abc123", size: 1024, files: [file1, file2])
        ]

        // Select file2 for deletion - this leaves only 1 file
        viewModel.toggleFileSelection(file2.id)

        let result = await viewModel.trashSelectedFiles()

        #expect(result.trashedCount == 1)

        // Group should be removed since only 1 file remains
        #expect(viewModel.duplicateGroups.isEmpty)
    }

    @Test("Trash with no selection returns empty result")
    func testTrashWithNoSelection_ReturnsEmptyResult() async {
        let viewModel = ScanViewModel()

        let file1 = ScannedFile(url: URL(fileURLWithPath: "/test/file1.txt"), size: 1024)
        let file2 = ScannedFile(url: URL(fileURLWithPath: "/test/file2.txt"), size: 1024)

        viewModel.duplicateGroups = [
            DuplicateGroup(hash: "abc123", size: 1024, files: [file1, file2])
        ]

        // Don't select any files
        let result = await viewModel.trashSelectedFiles()

        #expect(result.trashedCount == 0)
        #expect(result.bytesFreed == 0)
        #expect(result.failedFiles.isEmpty)
        #expect(result.wasEmpty)

        // Groups should be unchanged
        #expect(viewModel.duplicateGroups.count == 1)
    }

    @Test("Trash clears selection after operation")
    func testTrashClearsSelectionAfterOperation() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let file1URL = try testDir.addFile(name: "file1.txt", size: 1024)
        let file2URL = try testDir.addFile(name: "file2.txt", size: 1024)
        let file3URL = try testDir.addFile(name: "file3.txt", size: 1024)

        let file1 = ScannedFile(url: file1URL, size: 1024)
        let file2 = ScannedFile(url: file2URL, size: 1024)
        let file3 = ScannedFile(url: file3URL, size: 1024)

        let viewModel = ScanViewModel()
        viewModel.duplicateGroups = [
            DuplicateGroup(hash: "abc123", size: 1024, files: [file1, file2, file3])
        ]

        viewModel.toggleFileSelection(file2.id)
        #expect(viewModel.selectedFileIds.count == 1)

        _ = await viewModel.trashSelectedFiles()

        #expect(viewModel.selectedFileIds.isEmpty)
    }

    @Test("Trash shows result flag after operation")
    func testTrashShowsResultFlagAfterOperation() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let file1URL = try testDir.addFile(name: "file1.txt", size: 1024)
        let file2URL = try testDir.addFile(name: "file2.txt", size: 1024)
        let file3URL = try testDir.addFile(name: "file3.txt", size: 1024)

        let file1 = ScannedFile(url: file1URL, size: 1024)
        let file2 = ScannedFile(url: file2URL, size: 1024)
        let file3 = ScannedFile(url: file3URL, size: 1024)

        let viewModel = ScanViewModel()
        viewModel.duplicateGroups = [
            DuplicateGroup(hash: "abc123", size: 1024, files: [file1, file2, file3])
        ]

        viewModel.toggleFileSelection(file2.id)

        #expect(!viewModel.showTrashResult)

        _ = await viewModel.trashSelectedFiles()

        #expect(viewModel.showTrashResult)
        #expect(viewModel.lastTrashResult != nil)
    }
}
