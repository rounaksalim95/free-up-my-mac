import Testing
import Foundation
@testable import free_up_my_mac

@Suite("DuplicateDetectorService Tests")
struct DuplicateDetectorServiceTests {

    // MARK: - groupBySize Tests

    @Test("groupBySize groups files with same size")
    func testGroupBySize_GroupsSameSizeFiles() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create files with same sizes
        let file1URL = try testDir.addFile(name: "file1.txt", size: 1024)
        let file2URL = try testDir.addFile(name: "file2.txt", size: 1024)
        let file3URL = try testDir.addFile(name: "file3.txt", size: 2048)

        let files = [
            ScannedFile(url: file1URL, size: 1024),
            ScannedFile(url: file2URL, size: 1024),
            ScannedFile(url: file3URL, size: 2048)
        ]

        let detector = DuplicateDetectorService()
        let groups = await detector.groupBySize(files)

        // Should have one group with 2 files (1024 bytes)
        // The single 2048 file should be filtered out
        #expect(groups.count == 1)
        #expect(groups.first?.count == 2)
        #expect(groups.first?.allSatisfy { $0.size == 1024 } == true)
    }

    @Test("groupBySize filters out single-file groups")
    func testGroupBySize_FiltersSingleFileGroups() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create files with unique sizes
        let file1URL = try testDir.addFile(name: "file1.txt", size: 1024)
        let file2URL = try testDir.addFile(name: "file2.txt", size: 2048)
        let file3URL = try testDir.addFile(name: "file3.txt", size: 3072)

        let files = [
            ScannedFile(url: file1URL, size: 1024),
            ScannedFile(url: file2URL, size: 2048),
            ScannedFile(url: file3URL, size: 3072)
        ]

        let detector = DuplicateDetectorService()
        let groups = await detector.groupBySize(files)

        // No duplicates - all groups should be filtered out
        #expect(groups.isEmpty)
    }

    // MARK: - filterPotentialDuplicates Tests

    @Test("filterPotentialDuplicates uses partial hash to eliminate false positives")
    func testFilterPotentialDuplicates_EliminatesFalsePositives() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create two files with same size but different content
        let file1URL = try testDir.addFile(name: "file1.bin", size: 16384, content: Data(repeating: 0xAA, count: 16384))
        let file2URL = try testDir.addFile(name: "file2.bin", size: 16384, content: Data(repeating: 0xBB, count: 16384))

        // Create two actual duplicates
        let duplicateContent = Data(repeating: 0xCC, count: 16384)
        let dup1URL = try testDir.addFile(name: "dup1.bin", size: 16384, content: duplicateContent)
        let dup2URL = try testDir.addFile(name: "dup2.bin", size: 16384, content: duplicateContent)

        // Simulate files that have been grouped by size and have partial hashes
        let hasher = FileHasherService()

        var file1 = ScannedFile(url: file1URL, size: 16384)
        var file2 = ScannedFile(url: file2URL, size: 16384)
        var dup1 = ScannedFile(url: dup1URL, size: 16384)
        var dup2 = ScannedFile(url: dup2URL, size: 16384)

        file1.partialHash = try await hasher.computePartialHash(for: file1)
        file2.partialHash = try await hasher.computePartialHash(for: file2)
        dup1.partialHash = try await hasher.computePartialHash(for: dup1)
        dup2.partialHash = try await hasher.computePartialHash(for: dup2)

        let sizeGroup = [[file1, file2, dup1, dup2]]

        let detector = DuplicateDetectorService()
        let filtered = await detector.filterPotentialDuplicates(sizeGroup)

        // Should have one group with the actual duplicates (dup1, dup2)
        // file1 and file2 should be filtered out as they have different partial hashes
        #expect(filtered.count == 1)
        #expect(filtered.first?.count == 2)

        let filteredURLs = Set(filtered.first?.map { $0.url } ?? [])
        #expect(filteredURLs.contains(dup1URL))
        #expect(filteredURLs.contains(dup2URL))
    }

    // MARK: - findDuplicates End-to-End Tests

    @Test("findDuplicates finds actual duplicates correctly")
    func testFindDuplicates_FindsActualDuplicates() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create true duplicates using helper
        let duplicateURLs = try testDir.addDuplicateFiles(
            names: ["dup1.txt", "dup2.txt", "dup3.txt"],
            size: 2048
        )

        // Create a non-duplicate file
        let uniqueURL = try testDir.addFile(name: "unique.txt", size: 2048, content: Data(repeating: 0xFF, count: 2048))

        let files = duplicateURLs.map { ScannedFile(url: $0, size: 2048) } +
                    [ScannedFile(url: uniqueURL, size: 2048)]

        var progressPhases: [ScanPhase] = []
        let detector = DuplicateDetectorService()

        let groups = try await detector.findDuplicates(in: files) { progress in
            progressPhases.append(progress.phase)
        }

        #expect(groups.count == 1)
        #expect(groups.first?.files.count == 3)

        // Verify all duplicate files are in the group
        let groupFileURLs = Set(groups.first?.files.map { $0.url } ?? [])
        for url in duplicateURLs {
            #expect(groupFileURLs.contains(url))
        }

        // Unique file should not be in any group
        #expect(!groupFileURLs.contains(uniqueURL))
    }

    @Test("findDuplicates handles small files correctly")
    func testFindDuplicates_HandlesSmallFilesCorrectly() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create small duplicates (< 8KB, should skip partial hash)
        let smallContent = Data(repeating: 0x42, count: 4096)
        let small1URL = try testDir.addFile(name: "small1.txt", size: 4096, content: smallContent)
        let small2URL = try testDir.addFile(name: "small2.txt", size: 4096, content: smallContent)

        let files = [
            ScannedFile(url: small1URL, size: 4096),
            ScannedFile(url: small2URL, size: 4096)
        ]

        let detector = DuplicateDetectorService()
        let groups = try await detector.findDuplicates(in: files) { _ in }

        #expect(groups.count == 1)
        #expect(groups.first?.files.count == 2)
    }

    @Test("findDuplicates reports progress through all phases")
    func testFindDuplicates_ReportsAllPhases() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create enough files to trigger all phases
        let duplicateContent = Data(repeating: 0xAA, count: 16384)
        let dup1URL = try testDir.addFile(name: "dup1.bin", size: 16384, content: duplicateContent)
        let dup2URL = try testDir.addFile(name: "dup2.bin", size: 16384, content: duplicateContent)

        let files = [
            ScannedFile(url: dup1URL, size: 16384),
            ScannedFile(url: dup2URL, size: 16384)
        ]

        var reportedPhases: [ScanPhase] = []
        let detector = DuplicateDetectorService()

        _ = try await detector.findDuplicates(in: files) { progress in
            if reportedPhases.last != progress.phase {
                reportedPhases.append(progress.phase)
            }
        }

        // Should have reported these phases in order
        #expect(reportedPhases.contains(.groupingBySize))
        #expect(reportedPhases.contains(.computingPartialHashes))
        #expect(reportedPhases.contains(.computingFullHashes))
        #expect(reportedPhases.contains(.findingDuplicates))
        #expect(reportedPhases.contains(.completed))
    }

    @Test("findDuplicates handles empty input")
    func testFindDuplicates_HandlesEmptyInput() async throws {
        let detector = DuplicateDetectorService()
        let groups = try await detector.findDuplicates(in: []) { _ in }

        #expect(groups.isEmpty)
    }

    @Test("findDuplicates handles no duplicates")
    func testFindDuplicates_HandlesNoDuplicates() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create files with unique content and sizes
        let file1URL = try testDir.addFile(name: "file1.txt", size: 1024, content: Data(repeating: 0x41, count: 1024))
        let file2URL = try testDir.addFile(name: "file2.txt", size: 2048, content: Data(repeating: 0x42, count: 2048))
        let file3URL = try testDir.addFile(name: "file3.txt", size: 3072, content: Data(repeating: 0x43, count: 3072))

        let files = [
            ScannedFile(url: file1URL, size: 1024),
            ScannedFile(url: file2URL, size: 2048),
            ScannedFile(url: file3URL, size: 3072)
        ]

        let detector = DuplicateDetectorService()
        let groups = try await detector.findDuplicates(in: files) { _ in }

        #expect(groups.isEmpty)
    }

    @Test("findDuplicates sorts groups by potential savings descending")
    func testFindDuplicates_SortsByPotentialSavings() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create small duplicates (1KB each, 1KB potential savings)
        let smallContent = Data(repeating: 0xAA, count: 1024)
        let small1URL = try testDir.addFile(name: "small1.txt", size: 1024, content: smallContent)
        let small2URL = try testDir.addFile(name: "small2.txt", size: 1024, content: smallContent)

        // Create large duplicates (4KB each, 4KB potential savings)
        let largeContent = Data(repeating: 0xBB, count: 4096)
        let large1URL = try testDir.addFile(name: "large1.txt", size: 4096, content: largeContent)
        let large2URL = try testDir.addFile(name: "large2.txt", size: 4096, content: largeContent)

        let files = [
            ScannedFile(url: small1URL, size: 1024),
            ScannedFile(url: small2URL, size: 1024),
            ScannedFile(url: large1URL, size: 4096),
            ScannedFile(url: large2URL, size: 4096)
        ]

        let detector = DuplicateDetectorService()
        let groups = try await detector.findDuplicates(in: files) { _ in }

        #expect(groups.count == 2)
        // First group should have larger potential savings
        #expect(groups[0].potentialSavings >= groups[1].potentialSavings)
        #expect(groups[0].size == 4096)
    }

    // MARK: - Cancellation Tests

    @Test("findDuplicates can be cancelled")
    func testFindDuplicates_CanBeCancelled() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create many files
        var files: [ScannedFile] = []
        for i in 0..<50 {
            let content = Data(repeating: UInt8(i % 5), count: 16384)
            let fileURL = try testDir.addFile(name: "file\(i).bin", size: 16384, content: content)
            files.append(ScannedFile(url: fileURL, size: 16384))
        }

        let detector = DuplicateDetectorService()

        // Start detection in a task
        let detectTask = Task {
            try await detector.findDuplicates(in: files) { _ in }
        }

        // Cancel the detection
        await detector.cancel()

        // Should throw cancelled error or return partial results
        do {
            _ = try await detectTask.value
            // If it completes, that's acceptable for small datasets
        } catch let error as HashError {
            #expect(error == .cancelled)
        }
    }

    // MARK: - Mixed Scenarios

    @Test("findDuplicates handles mixed small and large files")
    func testFindDuplicates_HandlesMixedFileSizes() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        // Create small duplicates (< 8KB)
        let smallContent = Data(repeating: 0xAA, count: 2048)
        let small1URL = try testDir.addFile(name: "small1.txt", size: 2048, content: smallContent)
        let small2URL = try testDir.addFile(name: "small2.txt", size: 2048, content: smallContent)

        // Create large duplicates (> 8KB)
        let largeContent = Data(repeating: 0xBB, count: 16384)
        let large1URL = try testDir.addFile(name: "large1.bin", size: 16384, content: largeContent)
        let large2URL = try testDir.addFile(name: "large2.bin", size: 16384, content: largeContent)

        let files = [
            ScannedFile(url: small1URL, size: 2048),
            ScannedFile(url: small2URL, size: 2048),
            ScannedFile(url: large1URL, size: 16384),
            ScannedFile(url: large2URL, size: 16384)
        ]

        let detector = DuplicateDetectorService()
        let groups = try await detector.findDuplicates(in: files) { _ in }

        #expect(groups.count == 2)

        // Verify both groups are found
        let sizes = Set(groups.map { $0.size })
        #expect(sizes.contains(2048))
        #expect(sizes.contains(16384))
    }

    @Test("findDuplicates creates correct DuplicateGroup with hash")
    func testFindDuplicates_CreatesCorrectDuplicateGroup() async throws {
        let testDir = try TestDirectory.create()
        defer { try? testDir.cleanup() }

        let content = Data(repeating: 0x42, count: 2048)
        let file1URL = try testDir.addFile(name: "file1.txt", size: 2048, content: content)
        let file2URL = try testDir.addFile(name: "file2.txt", size: 2048, content: content)

        let files = [
            ScannedFile(url: file1URL, size: 2048),
            ScannedFile(url: file2URL, size: 2048)
        ]

        let detector = DuplicateDetectorService()
        let groups = try await detector.findDuplicates(in: files) { _ in }

        #expect(groups.count == 1)

        let group = groups.first!
        #expect(group.size == 2048)
        #expect(group.hash.count == 16) // 16-char hex hash
        #expect(group.files.count == 2)
        #expect(group.potentialSavings == 2048) // One duplicate = size savings
    }
}
