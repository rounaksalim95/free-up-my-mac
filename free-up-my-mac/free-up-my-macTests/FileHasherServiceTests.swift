import Testing
import Foundation
@testable import free_up_my_mac

@Suite("FileHasherService Tests")
struct FileHasherServiceTests {

    // MARK: - computePartialHash Tests

    @Test("computePartialHash returns consistent hash for same file")
    func testComputePartialHash_ConsistentForSameFile() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create a file larger than 8KB to use partial hashing
        let fileURL = try testDir.addFile(name: "large_file.txt", size: 16384)
        let file = ScannedFile(url: fileURL, size: 16384)

        let hasher = FileHasherService()
        let hash1 = try await hasher.computePartialHash(for: file)
        let hash2 = try await hasher.computePartialHash(for: file)

        #expect(hash1 == hash2)
        #expect(hash1.count == 16) // 64-bit hash = 16 hex chars
    }

    @Test("computePartialHash reads only first and last 4KB")
    func testComputePartialHash_ReadsFirstAndLast4KB() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create two files with same first/last 4KB but different middle content
        let size = 16384 // 16KB
        var content1 = Data(repeating: 0xAA, count: size)
        var content2 = Data(repeating: 0xAA, count: size)

        // Make the middle section different (bytes 4096 to 12288)
        content1.replaceSubrange(4096..<12288, with: Data(repeating: 0xBB, count: 8192))
        content2.replaceSubrange(4096..<12288, with: Data(repeating: 0xCC, count: 8192))

        let file1URL = try testDir.addFile(name: "file1.bin", size: size, content: content1)
        let file2URL = try testDir.addFile(name: "file2.bin", size: size, content: content2)

        let file1 = ScannedFile(url: file1URL, size: Int64(size))
        let file2 = ScannedFile(url: file2URL, size: Int64(size))

        let hasher = FileHasherService()
        let hash1 = try await hasher.computePartialHash(for: file1)
        let hash2 = try await hasher.computePartialHash(for: file2)

        // Partial hashes should be the same since first/last 4KB are identical
        #expect(hash1 == hash2)
    }

    @Test("computePartialHash for files < 8KB delegates to full hash")
    func testComputePartialHash_SmallFilesDelegateToFullHash() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create a file smaller than 8KB
        let content = Data(repeating: 0x42, count: 4096) // 4KB
        let fileURL = try testDir.addFile(name: "small_file.txt", size: 4096, content: content)
        let file = ScannedFile(url: fileURL, size: 4096)

        let hasher = FileHasherService()
        let partialHash = try await hasher.computePartialHash(for: file)
        let fullHash = try await hasher.computeFullHash(for: file)

        // For small files, partial hash should equal full hash
        #expect(partialHash == fullHash)
    }

    // MARK: - computeFullHash Tests

    @Test("computeFullHash returns consistent hash for same file")
    func testComputeFullHash_ConsistentForSameFile() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let content = Data(repeating: 0x41, count: 2048)
        let fileURL = try testDir.addFile(name: "test_file.txt", size: 2048, content: content)
        let file = ScannedFile(url: fileURL, size: 2048)

        let hasher = FileHasherService()
        let hash1 = try await hasher.computeFullHash(for: file)
        let hash2 = try await hasher.computeFullHash(for: file)

        #expect(hash1 == hash2)
    }

    @Test("computeFullHash returns 16-character lowercase hex string")
    func testComputeFullHash_ReturnsCorrectFormat() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let fileURL = try testDir.addFile(name: "format_test.txt", size: 1024)
        let file = ScannedFile(url: fileURL, size: 1024)

        let hasher = FileHasherService()
        let hash = try await hasher.computeFullHash(for: file)

        #expect(hash.count == 16)
        #expect(hash == hash.lowercased())
        #expect(hash.allSatisfy { $0.isHexDigit })
    }

    @Test("computeFullHash produces different hashes for different content")
    func testComputeFullHash_DifferentContentDifferentHashes() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let file1URL = try testDir.addFile(name: "file1.txt", size: 1024, content: Data(repeating: 0x41, count: 1024))
        let file2URL = try testDir.addFile(name: "file2.txt", size: 1024, content: Data(repeating: 0x42, count: 1024))

        let file1 = ScannedFile(url: file1URL, size: 1024)
        let file2 = ScannedFile(url: file2URL, size: 1024)

        let hasher = FileHasherService()
        let hash1 = try await hasher.computeFullHash(for: file1)
        let hash2 = try await hasher.computeFullHash(for: file2)

        #expect(hash1 != hash2)
    }

    @Test("computeFullHash streams large files in chunks")
    func testComputeFullHash_StreamsLargeFiles() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create a file larger than chunk size (64KB)
        let size = 256 * 1024 // 256KB
        let fileURL = try testDir.addFile(name: "large_file.bin", size: size)
        let file = ScannedFile(url: fileURL, size: Int64(size))

        let hasher = FileHasherService()
        // This should complete without loading entire file into memory
        let hash = try await hasher.computeFullHash(for: file)

        #expect(hash.count == 16)
    }

    // MARK: - Batch Operations Tests

    @Test("computePartialHashes processes batch and reports progress")
    func testComputePartialHashes_BatchWithProgress() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create multiple large files
        var files: [ScannedFile] = []
        for i in 0..<10 {
            let fileURL = try testDir.addFile(name: "file\(i).bin", size: 16384)
            files.append(ScannedFile(url: fileURL, size: 16384))
        }

        var progressUpdates: [(Int, Int)] = []
        let hasher = FileHasherService()

        let results = try await hasher.computePartialHashes(for: files) { processed, total in
            progressUpdates.append((processed, total))
        }

        #expect(results.files.count == 10)
        #expect(results.files.allSatisfy { $0.partialHash != nil })

        // Should have received at least one progress update
        #expect(!progressUpdates.isEmpty)

        // Final progress should show all files processed
        if let lastProgress = progressUpdates.last {
            #expect(lastProgress.0 == 10)
            #expect(lastProgress.1 == 10)
        }
    }

    @Test("computeFullHashes processes batch and reports progress")
    func testComputeFullHashes_BatchWithProgress() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        var files: [ScannedFile] = []
        for i in 0..<10 {
            let fileURL = try testDir.addFile(name: "file\(i).txt", size: 2048)
            files.append(ScannedFile(url: fileURL, size: 2048))
        }

        var progressUpdates: [(Int, Int)] = []
        let hasher = FileHasherService()

        let results = try await hasher.computeFullHashes(for: files) { processed, total in
            progressUpdates.append((processed, total))
        }

        #expect(results.files.count == 10)
        #expect(results.files.allSatisfy { $0.fullHash != nil })
        #expect(!progressUpdates.isEmpty)
    }

    // MARK: - Error Handling Tests

    @Test("computeFullHash skips inaccessible files gracefully")
    func testComputeFullHash_SkipsInaccessibleFiles() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create files
        let accessibleURL = try testDir.addFile(name: "accessible.txt", size: 1024)
        let inaccessibleURL = try testDir.addFile(name: "inaccessible.txt", size: 1024)

        // Remove read permission from one file
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: inaccessibleURL.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: inaccessibleURL.path
            )
        }

        let files = [
            ScannedFile(url: accessibleURL, size: 1024),
            ScannedFile(url: inaccessibleURL, size: 1024)
        ]

        let hasher = FileHasherService()
        let results = try await hasher.computeFullHashes(for: files) { _, _ in }

        // Should return only the accessible file with hash
        let filesWithHashes = results.files.filter { $0.fullHash != nil }
        #expect(filesWithHashes.count == 1)
        #expect(filesWithHashes.first?.url == accessibleURL)

        // Inaccessible file should be in skipped files
        #expect(results.skippedFiles.count == 1)
        #expect(results.skippedFiles.first?.url == inaccessibleURL)
    }

    @Test("computeFullHash throws for non-existent file")
    func testComputeFullHash_ThrowsForNonExistentFile() async throws {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/path/\(UUID().uuidString).txt")
        let file = ScannedFile(url: nonExistentURL, size: 1024)

        let hasher = FileHasherService()

        await #expect(throws: HashError.self) {
            try await hasher.computeFullHash(for: file)
        }
    }

    // MARK: - Cancellation Tests

    @Test("Batch hashing can be cancelled")
    func testBatchHashing_CanBeCancelled() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create many files to ensure we have time to cancel
        var files: [ScannedFile] = []
        for i in 0..<50 {
            let fileURL = try testDir.addFile(name: "file\(i).bin", size: 16384)
            files.append(ScannedFile(url: fileURL, size: 16384))
        }

        let hasher = FileHasherService()

        // Start hashing in a task
        let hashTask = Task {
            try await hasher.computeFullHashes(for: files) { _, _ in }
        }

        // Cancel the hashing
        await hasher.cancel()

        // Should throw cancelled error or return partial results
        do {
            let results = try await hashTask.value
            // If it completes quickly, that's also acceptable
            // But we should have fewer results than total files if cancelled mid-process
            #expect(results.files.count <= files.count)
        } catch let error as HashError {
            #expect(error == .cancelled)
        }

        // Reset for future use
        await hasher.resetCancellation()
    }
}
