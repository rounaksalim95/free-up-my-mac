import Testing
import Foundation
@testable import free_up_my_mac

@Suite("FileOperationService Tests")
struct FileOperationServiceTests {

    // MARK: - Single File Move to Trash Tests

    @Test("Move single file to trash succeeds")
    func testMoveToTrash_SingleFile_Succeeds() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let fileURL = try testDir.addFile(name: "test.txt", size: 1024)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let service = FileOperationService()
        try await service.moveToTrash(at: fileURL)

        // File should no longer exist at original location
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("Move to trash throws fileNotFound for missing file")
    func testMoveToTrash_FileNotFound_ThrowsError() async throws {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString).txt")

        let service = FileOperationService()

        await #expect(throws: FileOperationError.self) {
            try await service.moveToTrash(at: nonExistentURL)
        }
    }

    // MARK: - Batch Move to Trash Tests

    @Test("Move multiple files to trash returns total bytes freed")
    func testMoveToTrash_MultipleFiles_ReturnsBytesFreed() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let file1URL = try testDir.addFile(name: "file1.txt", size: 1024)
        let file2URL = try testDir.addFile(name: "file2.txt", size: 2048)
        let file3URL = try testDir.addFile(name: "file3.txt", size: 512)

        let files = [
            ScannedFile(url: file1URL, size: 1024),
            ScannedFile(url: file2URL, size: 2048),
            ScannedFile(url: file3URL, size: 512)
        ]

        let service = FileOperationService()
        let bytesFreed = try await service.moveToTrash(files)

        // Should return total bytes of all files
        #expect(bytesFreed == 3584)

        // All files should be removed
        #expect(!FileManager.default.fileExists(atPath: file1URL.path))
        #expect(!FileManager.default.fileExists(atPath: file2URL.path))
        #expect(!FileManager.default.fileExists(atPath: file3URL.path))
    }

    @Test("Move empty array to trash returns zero")
    func testMoveToTrash_EmptyArray_ReturnsZero() async throws {
        let service = FileOperationService()
        let bytesFreed = try await service.moveToTrash([])

        #expect(bytesFreed == 0)
    }

    @Test("Partial failure reports errors but continues with other files")
    func testMoveToTrash_PartialFailure_ReportsErrors() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create one real file
        let existingURL = try testDir.addFile(name: "existing.txt", size: 1024)

        // One non-existent file
        let nonExistentURL = testDir.url.appendingPathComponent("missing.txt")

        let files = [
            ScannedFile(url: existingURL, size: 1024),
            ScannedFile(url: nonExistentURL, size: 2048)
        ]

        let service = FileOperationService()

        do {
            _ = try await service.moveToTrash(files)
            Issue.record("Expected partialFailure error")
        } catch let error as FileOperationError {
            if case .partialFailure(let trashedCount, let bytesFreed, let errors) = error {
                #expect(trashedCount == 1)
                #expect(bytesFreed == 1024)
                #expect(errors.count == 1)
            } else {
                Issue.record("Expected partialFailure, got: \(error)")
            }
        }

        // Existing file should still be trashed
        #expect(!FileManager.default.fileExists(atPath: existingURL.path))
    }

    // MARK: - Delete Duplicates Tests

    @Test("Delete duplicates keeps original file")
    func testDeleteDuplicates_KeepsOriginal() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let original = try testDir.addFile(name: "original.txt", size: 1024)
        let dup1 = try testDir.addFile(name: "dup1.txt", size: 1024)
        let dup2 = try testDir.addFile(name: "dup2.txt", size: 1024)

        let originalFile = ScannedFile(url: original, size: 1024)
        let duplicates = [
            originalFile,
            ScannedFile(url: dup1, size: 1024),
            ScannedFile(url: dup2, size: 1024)
        ]

        let group = DuplicateGroup(hash: "abc123", size: 1024, files: duplicates)

        let service = FileOperationService()
        let bytesFreed = try await service.deleteDuplicates(in: group, keeping: originalFile)

        // Should free 2 files worth
        #expect(bytesFreed == 2048)

        // Original should still exist
        #expect(FileManager.default.fileExists(atPath: original.path))

        // Duplicates should be removed
        #expect(!FileManager.default.fileExists(atPath: dup1.path))
        #expect(!FileManager.default.fileExists(atPath: dup2.path))
    }

    // MARK: - Reveal and Open Tests

    @Test("Reveal in Finder does not throw")
    func testRevealInFinder_DoesNotThrow() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let fileURL = try testDir.addFile(name: "test.txt", size: 1024)
        let file = ScannedFile(url: fileURL, size: 1024)

        let service = FileOperationService()

        // This is a nonisolated method, just verify it doesn't crash
        service.revealInFinder(file)
    }

    @Test("Open file does not throw")
    func testOpenFile_DoesNotThrow() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let fileURL = try testDir.addFile(name: "test.txt", size: 1024)
        let file = ScannedFile(url: fileURL, size: 1024)

        let service = FileOperationService()

        // This is a nonisolated method, just verify it doesn't crash
        service.openFile(file)
    }
}
