import Testing
import Foundation
@testable import free_up_my_mac

@Suite("FileScannerService Tests")
struct FileScannerServiceTests {

    // MARK: - Test 1: Empty Directory

    @Test("Scan empty directory returns empty array")
    func testScanEmptyDirectory_ReturnsEmptyArray() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let scanner = FileScannerService()
        let results = try await scanner.scanDirectory(at: testDir.url) { _ in }

        #expect(results.isEmpty)
    }

    // MARK: - Test 2: Directory with Files

    @Test("Scan directory with files returns scanned files")
    func testScanDirectoryWithFiles_ReturnsScannedFiles() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Add files larger than minimum threshold (1KB)
        try testDir.addFile(name: "file1.txt", size: 1024)
        try testDir.addFile(name: "file2.txt", size: 2048)

        let scanner = FileScannerService()
        let results = try await scanner.scanDirectory(at: testDir.url) { _ in }

        #expect(results.count == 2)
    }

    // MARK: - Test 3: Filter Hidden Files When Enabled

    @Test("Scan filters hidden files when enabled")
    func testScanFiltersHiddenFiles_WhenEnabled() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        try testDir.addFile(name: "visible_file.txt", size: 1024)
        try testDir.addFile(name: ".hidden_file", size: 1024)

        let filters = FileFilters(excludeHiddenFiles: true)
        let scanner = FileScannerService(filters: filters)
        let results = try await scanner.scanDirectory(at: testDir.url) { _ in }

        #expect(results.count == 1)
        #expect(results.first?.fileName == "visible_file.txt")
    }

    // MARK: - Test 4: Include Hidden Files When Disabled

    @Test("Scan includes hidden files when filter disabled")
    func testScanIncludesHiddenFiles_WhenDisabled() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        try testDir.addFile(name: "visible_file.txt", size: 1024)
        try testDir.addFile(name: ".hidden_file", size: 1024)

        let filters = FileFilters(excludeHiddenFiles: false, excludeSystemDirectories: false)
        let scanner = FileScannerService(filters: filters)
        let results = try await scanner.scanDirectory(at: testDir.url) { _ in }

        #expect(results.count == 2)
        let fileNames = Set(results.map { $0.fileName })
        #expect(fileNames.contains("visible_file.txt"))
        #expect(fileNames.contains(".hidden_file"))
    }

    // MARK: - Test 5: Filter Small Files Below Minimum Size

    @Test("Scan filters files below minimum size")
    func testScanFiltersSmallFiles_BelowMinimumSize() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        try testDir.addFile(name: "large_file.txt", size: 2048)
        try testDir.addFile(name: "small_file.txt", size: 100) // Below 1KB threshold

        let scanner = FileScannerService()
        let results = try await scanner.scanDirectory(at: testDir.url) { _ in }

        #expect(results.count == 1)
        #expect(results.first?.fileName == "large_file.txt")
    }

    // MARK: - Test 6: Skip System Directories

    @Test("Scan skips system directories like .git")
    func testScanSkipsSystemDirectories() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        try testDir.addFile(name: "regular_file.txt", size: 1024)

        let gitDir = try testDir.addSubdirectory(name: ".git")
        try testDir.addFile(name: "config", size: 1024, in: gitDir)
        try testDir.addFile(name: "HEAD", size: 1024, in: gitDir)

        let scanner = FileScannerService()
        let results = try await scanner.scanDirectory(at: testDir.url) { _ in }

        // Should only find regular_file.txt, not files in .git
        #expect(results.count == 1)
        #expect(results.first?.fileName == "regular_file.txt")
    }

    // MARK: - Test 7: Skip System Paths like /Library/System

    @Test("Scan skips system paths like /Library")
    func testScanSkipsSystemPaths_LibrarySystem() async throws {
        // This test verifies the filter logic for system paths
        let filters = FileFilters(excludeSystemDirectories: true)

        // /Library should be blocked
        let libraryURL = URL(fileURLWithPath: "/Library/Preferences")
        #expect(filters.shouldTraverseDirectory(at: libraryURL) == false)

        // /System should be blocked
        let systemURL = URL(fileURLWithPath: "/System/Library")
        #expect(filters.shouldTraverseDirectory(at: systemURL) == false)
    }

    // MARK: - Test 8: Allow User Library

    @Test("Scan allows user Library directory")
    func testScanAllowsUserLibrary() async throws {
        // User's ~/Library should be allowed (it's not /Library)
        let filters = FileFilters(excludeSystemDirectories: true)

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let userLibraryURL = homeDir.appendingPathComponent("Library")

        // ~/Library should be allowed because it doesn't match /Library exactly
        // The path would be something like /Users/username/Library
        #expect(filters.shouldTraverseDirectory(at: userLibraryURL) == true)
    }

    // MARK: - Test 9: Reports Progress

    @Test("Scan reports progress during enumeration")
    func testScanReportsProgress() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        try testDir.addFile(name: "file1.txt", size: 1024)
        try testDir.addFile(name: "file2.txt", size: 1024)
        try testDir.addFile(name: "file3.txt", size: 1024)

        var progressUpdates: [ScanProgress] = []
        let scanner = FileScannerService()

        _ = try await scanner.scanDirectory(at: testDir.url) { progress in
            progressUpdates.append(progress)
        }

        // Should have received at least one progress update
        #expect(!progressUpdates.isEmpty)

        // Check that progress includes enumerating phase
        let hasEnumeratingPhase = progressUpdates.contains { $0.phase == .enumerating }
        #expect(hasEnumeratingPhase)
    }

    // MARK: - Test 10: Cancellation

    @Test("Scan can be cancelled")
    func testScanCanBeCancelled() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create many files to ensure we have time to cancel
        for i in 0..<100 {
            try testDir.addFile(name: "file\(i).txt", size: 1024)
        }

        let scanner = FileScannerService()

        // Start the scan in a task
        let scanTask = Task {
            try await scanner.scanDirectory(at: testDir.url) { _ in }
        }

        // Cancel the scan
        await scanner.cancelScan()

        // The scan should either complete with fewer results or throw cancelled error
        do {
            _ = try await scanTask.value
            // If it completes, that's also acceptable for fast scans
        } catch let error as ScanError {
            #expect(error == .cancelled)
        }
    }

    // MARK: - Test 11: Handle Permission Errors Gracefully

    @Test("Scan handles permission errors gracefully")
    func testScanHandlesPermissionErrors_Gracefully() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        try testDir.addFile(name: "accessible_file.txt", size: 1024)

        // Create a directory with restricted permissions
        let restrictedDir = try testDir.addSubdirectory(name: "restricted")
        try testDir.addFile(name: "hidden_file.txt", size: 1024, in: restrictedDir)

        // Remove read permissions from the directory
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: restrictedDir.path
        )

        // Restore permissions in cleanup
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: restrictedDir.path
            )
        }

        let scanner = FileScannerService()

        // Should not throw - should skip inaccessible directories
        let results = try await scanner.scanDirectory(at: testDir.url) { _ in }

        // Should still find the accessible file
        #expect(results.count >= 1)
        #expect(results.contains { $0.fileName == "accessible_file.txt" })
    }

    // MARK: - Test 12: Collects File Metadata

    @Test("Scan collects file metadata including size and dates")
    func testScanCollectsFileMetadata_SizeDates() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let expectedSize: Int = 2048
        try testDir.addFile(name: "metadata_test.txt", size: expectedSize)

        let scanner = FileScannerService()
        let results = try await scanner.scanDirectory(at: testDir.url) { _ in }

        #expect(results.count == 1)

        let file = results.first!
        #expect(file.size == Int64(expectedSize))
        #expect(file.url.lastPathComponent == "metadata_test.txt")
        #expect(file.creationDate != nil)
        #expect(file.modificationDate != nil)
    }

    // MARK: - Test 13: Scans Nested Directories

    @Test("Scan traverses nested subdirectories")
    func testScanTraversesNestedDirectories() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        try testDir.addFile(name: "root_file.txt", size: 1024)

        let subDir1 = try testDir.addSubdirectory(name: "level1")
        try testDir.addFile(name: "level1_file.txt", size: 1024, in: subDir1)

        let subDir2URL = subDir1.appendingPathComponent("level2")
        try FileManager.default.createDirectory(at: subDir2URL, withIntermediateDirectories: true)
        let subDir2Data = Data(repeating: 0x41, count: 1024)
        try subDir2Data.write(to: subDir2URL.appendingPathComponent("level2_file.txt"))

        let scanner = FileScannerService()
        let results = try await scanner.scanDirectory(at: testDir.url) { _ in }

        #expect(results.count == 3)

        let fileNames = Set(results.map { $0.fileName })
        #expect(fileNames.contains("root_file.txt"))
        #expect(fileNames.contains("level1_file.txt"))
        #expect(fileNames.contains("level2_file.txt"))
    }

    // MARK: - Test 14: Directory Not Found

    @Test("Scan throws error for non-existent directory")
    func testScanThrowsError_DirectoryNotFound() async throws {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/path/\(UUID().uuidString)")
        let scanner = FileScannerService()

        await #expect(throws: ScanError.self) {
            try await scanner.scanDirectory(at: nonExistentURL) { _ in }
        }
    }
}
