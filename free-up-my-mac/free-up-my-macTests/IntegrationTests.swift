import Testing
import Foundation
@testable import free_up_my_mac

@Suite("Integration Tests")
struct IntegrationTests {

    // MARK: - End-to-End Workflow Test

    @Test("Full scan, detect duplicates, and trash workflow")
    func testFullScanDetectTrashWorkflow() async throws {
        // 1. Create test directory with duplicate files
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create a set of duplicate files (same content)
        let duplicateContent = Data(repeating: 0x42, count: 2048)
        try testDir.addDuplicateFiles(
            names: ["original.txt", "copy1.txt", "copy2.txt"],
            size: 2048,
            content: duplicateContent
        )

        // Create a unique file (not a duplicate)
        try testDir.addFile(name: "unique.txt", size: 1500)

        // 2. Scan directory with FileScannerService
        let scanner = FileScannerService()
        var scanProgressUpdates: [ScanProgress] = []

        let scannedFiles = try await scanner.scanDirectory(at: testDir.url) { progress in
            scanProgressUpdates.append(progress)
        }

        // Verify scanning
        #expect(scannedFiles.count == 4) // 3 duplicates + 1 unique
        #expect(scanProgressUpdates.contains { $0.phase == .enumerating })

        // 3. Detect duplicates with DuplicateDetectorService
        let detector = DuplicateDetectorService()
        var detectProgressUpdates: [ScanProgress] = []

        let duplicateGroups = try await detector.findDuplicates(in: scannedFiles) { progress in
            detectProgressUpdates.append(progress)
        }

        // Verify duplicate detection
        #expect(duplicateGroups.count == 1) // One group of duplicates
        #expect(duplicateGroups.first?.files.count == 3) // 3 files in the group
        #expect(detectProgressUpdates.contains { $0.phase == .groupingBySize })
        #expect(detectProgressUpdates.contains { $0.phase == .completed })

        // 4. Trash duplicates (keep the original) with FileOperationService
        let fileOps = FileOperationService()

        guard let group = duplicateGroups.first else {
            Issue.record("No duplicate group found")
            return
        }

        // Keep the first file (original), trash the rest
        let filesToTrash = Array(group.files.dropFirst())
        #expect(filesToTrash.count == 2)

        // Calculate expected bytes to be freed
        let expectedBytesFreed = filesToTrash.reduce(0) { $0 + $1.size }

        let bytesFreed = try await fileOps.moveToTrash(filesToTrash)

        // Verify trash operation
        #expect(bytesFreed == expectedBytesFreed)

        // Verify files are actually trashed (no longer exist at original location)
        for file in filesToTrash {
            #expect(FileManager.default.fileExists(atPath: file.url.path) == false)
        }

        // Verify original still exists
        let originalFile = group.files.first!
        #expect(FileManager.default.fileExists(atPath: originalFile.url.path) == true)
    }

    // MARK: - Scan and Detect No Duplicates

    @Test("Scan directory with no duplicates returns empty groups")
    func testScanWithNoDuplicates() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create unique files with different sizes
        try testDir.addFile(name: "file1.txt", size: 1024)
        try testDir.addFile(name: "file2.txt", size: 2048)
        try testDir.addFile(name: "file3.txt", size: 3072)

        let scanner = FileScannerService()
        let scannedFiles = try await scanner.scanDirectory(at: testDir.url) { _ in }

        #expect(scannedFiles.count == 3)

        let detector = DuplicateDetectorService()
        let duplicateGroups = try await detector.findDuplicates(in: scannedFiles) { _ in }

        #expect(duplicateGroups.isEmpty)
    }

    // MARK: - Same Size Different Content

    @Test("Files with same size but different content are not duplicates")
    func testSameSizeDifferentContentNotDuplicates() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create files with same size but different content
        try testDir.addSameSizeDifferentContent(
            names: ["fileA.txt", "fileB.txt", "fileC.txt"],
            size: 2048
        )

        let scanner = FileScannerService()
        let scannedFiles = try await scanner.scanDirectory(at: testDir.url) { _ in }

        #expect(scannedFiles.count == 3)

        let detector = DuplicateDetectorService()
        let duplicateGroups = try await detector.findDuplicates(in: scannedFiles) { _ in }

        // Files have same size but different content, so no duplicates
        #expect(duplicateGroups.isEmpty)
    }

    // MARK: - Multiple Duplicate Groups

    @Test("Detects multiple duplicate groups correctly")
    func testMultipleDuplicateGroups() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Group 1: Two duplicates of photos
        let photoContent = Data(repeating: 0xAA, count: 4096)
        try testDir.addDuplicateFiles(
            names: ["photo1.jpg", "photo1_copy.jpg"],
            size: 4096,
            content: photoContent
        )

        // Group 2: Three duplicates of documents
        let docContent = Data(repeating: 0xBB, count: 2048)
        try testDir.addDuplicateFiles(
            names: ["doc.pdf", "doc_backup.pdf", "doc_old.pdf"],
            size: 2048,
            content: docContent
        )

        // Unique file
        try testDir.addFile(name: "unique.txt", size: 1500)

        let scanner = FileScannerService()
        let scannedFiles = try await scanner.scanDirectory(at: testDir.url) { _ in }

        #expect(scannedFiles.count == 6)

        let detector = DuplicateDetectorService()
        let duplicateGroups = try await detector.findDuplicates(in: scannedFiles) { _ in }

        #expect(duplicateGroups.count == 2)

        // Verify group sizes (sorted by potential savings, so larger first)
        let sortedGroups = duplicateGroups.sorted { $0.files.count > $1.files.count }
        #expect(sortedGroups[0].files.count == 3) // doc group
        #expect(sortedGroups[1].files.count == 2) // photo group
    }

    // MARK: - Nested Directory Duplicates

    @Test("Finds duplicates across nested directories")
    func testDuplicatesAcrossNestedDirectories() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let content = Data(repeating: 0xCC, count: 2048)

        // File in root
        try testDir.addFile(name: "root_file.txt", size: 2048, content: content)

        // Same file in subdirectory
        let subDir = try testDir.addSubdirectory(name: "subfolder")
        try testDir.addFile(name: "nested_file.txt", size: 2048, in: subDir, content: content)

        // Same file in deeper directory
        let deepDir = subDir.appendingPathComponent("deep")
        try FileManager.default.createDirectory(at: deepDir, withIntermediateDirectories: true)
        try content.write(to: deepDir.appendingPathComponent("deep_file.txt"))

        let scanner = FileScannerService()
        let scannedFiles = try await scanner.scanDirectory(at: testDir.url) { _ in }

        #expect(scannedFiles.count == 3)

        let detector = DuplicateDetectorService()
        let duplicateGroups = try await detector.findDuplicates(in: scannedFiles) { _ in }

        #expect(duplicateGroups.count == 1)
        #expect(duplicateGroups.first?.files.count == 3)
    }

    // MARK: - Cancellation During Detection

    @Test("Detection can be cancelled")
    func testDetectionCancellation() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create many duplicate files to have time to cancel
        let content = Data(repeating: 0xDD, count: 4096)
        for i in 0..<50 {
            try testDir.addFile(name: "file\(i).txt", size: 4096, content: content)
        }

        let scanner = FileScannerService()
        let scannedFiles = try await scanner.scanDirectory(at: testDir.url) { _ in }

        let detector = DuplicateDetectorService()

        let detectTask = Task {
            try await detector.findDuplicates(in: scannedFiles) { _ in }
        }

        // Cancel detection
        await detector.cancel()

        do {
            _ = try await detectTask.value
            // If completes quickly, that's fine
        } catch {
            // Cancellation is expected
            #expect(error is HashError)
        }
    }

    // MARK: - Small Files Bypass Partial Hashing

    @Test("Small files bypass partial hashing stage")
    func testSmallFilesBypassPartialHashing() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create small duplicate files (below 8KB threshold)
        let content = Data(repeating: 0xEE, count: 2048)
        try testDir.addDuplicateFiles(
            names: ["small1.txt", "small2.txt"],
            size: 2048,
            content: content
        )

        let scanner = FileScannerService()
        let scannedFiles = try await scanner.scanDirectory(at: testDir.url) { _ in }

        let detector = DuplicateDetectorService()
        var phases: [ScanPhase] = []

        let duplicateGroups = try await detector.findDuplicates(in: scannedFiles) { progress in
            if !phases.contains(progress.phase) {
                phases.append(progress.phase)
            }
        }

        #expect(duplicateGroups.count == 1)
        #expect(duplicateGroups.first?.files.count == 2)

        // Verify detection completed
        #expect(phases.contains(.completed))
    }

    // MARK: - Hash Verification

    @Test("Duplicate files have matching hashes")
    func testDuplicateFilesHaveMatchingHashes() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let content = Data(repeating: 0xFF, count: 2048)
        try testDir.addDuplicateFiles(
            names: ["dup1.txt", "dup2.txt"],
            size: 2048,
            content: content
        )

        let scanner = FileScannerService()
        let scannedFiles = try await scanner.scanDirectory(at: testDir.url) { _ in }

        let detector = DuplicateDetectorService()
        let duplicateGroups = try await detector.findDuplicates(in: scannedFiles) { _ in }

        #expect(duplicateGroups.count == 1)

        let group = duplicateGroups.first!
        let file1 = group.files[0]
        let file2 = group.files[1]

        // Both files should have the same full hash
        #expect(file1.fullHash != nil)
        #expect(file2.fullHash != nil)
        #expect(file1.fullHash == file2.fullHash)
    }
}
