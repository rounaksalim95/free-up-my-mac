import Testing
import Foundation
@testable import free_up_my_mac

@Suite("LargeFileGroup Tests")
struct LargeFileGroupTests {

    // MARK: - Test 1: Basic Properties

    @Test("LargeFileGroup has correct basic properties")
    func testBasicProperties() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Documents/video.mp4"), size: 500 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/Documents/backup.zip"), size: 200 * 1024 * 1024)
        ]

        let group = LargeFileGroup(
            folderURL: URL(fileURLWithPath: "/Documents"),
            files: files
        )

        #expect(group.folderName == "Documents")
        #expect(group.folderPath == "/Documents")
        #expect(group.fileCount == 2)
    }

    // MARK: - Test 2: Total Size Calculation

    @Test("LargeFileGroup calculates total size correctly")
    func testTotalSizeCalculation() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Folder/file1.txt"), size: 100 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/file2.txt"), size: 200 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/file3.txt"), size: 300 * 1024 * 1024)
        ]

        let group = LargeFileGroup(
            folderURL: URL(fileURLWithPath: "/Folder"),
            files: files
        )

        let expectedTotal: Int64 = 600 * 1024 * 1024
        #expect(group.totalSize == expectedTotal)
    }

    // MARK: - Test 3: Sort By Size Descending

    @Test("LargeFileGroup sorts files by size descending")
    func testSortBySizeDescending() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Folder/small.txt"), size: 100),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/large.txt"), size: 300),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/medium.txt"), size: 200)
        ]

        let group = LargeFileGroup(
            folderURL: URL(fileURLWithPath: "/Folder"),
            files: files
        )

        let sorted = group.filesSorted(by: .sizeDesc)

        #expect(sorted[0].url.lastPathComponent == "large.txt")
        #expect(sorted[1].url.lastPathComponent == "medium.txt")
        #expect(sorted[2].url.lastPathComponent == "small.txt")
    }

    // MARK: - Test 4: Sort By Size Ascending

    @Test("LargeFileGroup sorts files by size ascending")
    func testSortBySizeAscending() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Folder/small.txt"), size: 100),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/large.txt"), size: 300),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/medium.txt"), size: 200)
        ]

        let group = LargeFileGroup(
            folderURL: URL(fileURLWithPath: "/Folder"),
            files: files
        )

        let sorted = group.filesSorted(by: .sizeAsc)

        #expect(sorted[0].url.lastPathComponent == "small.txt")
        #expect(sorted[1].url.lastPathComponent == "medium.txt")
        #expect(sorted[2].url.lastPathComponent == "large.txt")
    }

    // MARK: - Test 5: Sort By Date Descending

    @Test("LargeFileGroup sorts files by date descending (newest first)")
    func testSortByDateDescending() async throws {
        let oldDate = Date().addingTimeInterval(-86400 * 365)
        let newDate = Date().addingTimeInterval(-86400)
        let middleDate = Date().addingTimeInterval(-86400 * 180)

        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Folder/old.txt"), size: 100, modificationDate: oldDate),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/new.txt"), size: 100, modificationDate: newDate),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/middle.txt"), size: 100, modificationDate: middleDate)
        ]

        let group = LargeFileGroup(
            folderURL: URL(fileURLWithPath: "/Folder"),
            files: files
        )

        let sorted = group.filesSorted(by: .dateDesc)

        #expect(sorted[0].url.lastPathComponent == "new.txt")
        #expect(sorted[1].url.lastPathComponent == "middle.txt")
        #expect(sorted[2].url.lastPathComponent == "old.txt")
    }

    // MARK: - Test 6: Sort By Date Ascending

    @Test("LargeFileGroup sorts files by date ascending (oldest first)")
    func testSortByDateAscending() async throws {
        let oldDate = Date().addingTimeInterval(-86400 * 365)
        let newDate = Date().addingTimeInterval(-86400)
        let middleDate = Date().addingTimeInterval(-86400 * 180)

        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Folder/old.txt"), size: 100, modificationDate: oldDate),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/new.txt"), size: 100, modificationDate: newDate),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/middle.txt"), size: 100, modificationDate: middleDate)
        ]

        let group = LargeFileGroup(
            folderURL: URL(fileURLWithPath: "/Folder"),
            files: files
        )

        let sorted = group.filesSorted(by: .dateAsc)

        #expect(sorted[0].url.lastPathComponent == "old.txt")
        #expect(sorted[1].url.lastPathComponent == "middle.txt")
        #expect(sorted[2].url.lastPathComponent == "new.txt")
    }

    // MARK: - Test 7: Combined Score Sorting

    @Test("LargeFileGroup combined score favors large old files")
    func testCombinedScoreSorting() async throws {
        let oldDate = Date().addingTimeInterval(-86400 * 365) // 1 year old
        let newDate = Date().addingTimeInterval(-86400) // 1 day old

        // Large old file should score highest (60% size * large + 40% age * old)
        // Small new file should score lowest
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Folder/large_old.txt"), size: 1000, modificationDate: oldDate),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/small_new.txt"), size: 100, modificationDate: newDate),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/large_new.txt"), size: 1000, modificationDate: newDate)
        ]

        let group = LargeFileGroup(
            folderURL: URL(fileURLWithPath: "/Folder"),
            files: files
        )

        let dateRange = (oldest: oldDate, newest: newDate)
        let sorted = group.filesSorted(by: .combinedScoreDesc, dateRange: dateRange)

        // Large old file should be first (highest combined score)
        #expect(sorted[0].url.lastPathComponent == "large_old.txt")
        // Small new file should be last (lowest combined score)
        #expect(sorted[2].url.lastPathComponent == "small_new.txt")
    }

    // MARK: - Test 8: Empty Files Array

    @Test("LargeFileGroup with empty files has zero size")
    func testEmptyFilesArray() async throws {
        let group = LargeFileGroup(
            folderURL: URL(fileURLWithPath: "/Folder"),
            files: []
        )

        #expect(group.totalSize == 0)
        #expect(group.fileCount == 0)
    }

    // MARK: - Test 9: Hashable Conformance

    @Test("LargeFileGroup is hashable")
    func testHashableConformance() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Folder/file.txt"), size: 100)
        ]

        let group1 = LargeFileGroup(
            id: UUID(),
            folderURL: URL(fileURLWithPath: "/Folder"),
            files: files
        )

        let group2 = LargeFileGroup(
            id: UUID(),
            folderURL: URL(fileURLWithPath: "/Folder"),
            files: files
        )

        // Different IDs should result in different groups
        var set: Set<LargeFileGroup> = []
        set.insert(group1)
        set.insert(group2)

        #expect(set.count == 2)
    }

    // MARK: - Test 10: Combined Score Without Date Range Falls Back To Size

    @Test("Combined score without date range falls back to size sorting")
    func testCombinedScoreWithoutDateRange() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Folder/small.txt"), size: 100),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/large.txt"), size: 300),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/medium.txt"), size: 200)
        ]

        let group = LargeFileGroup(
            folderURL: URL(fileURLWithPath: "/Folder"),
            files: files
        )

        let sorted = group.filesSorted(by: .combinedScoreDesc, dateRange: nil)

        // Without date range, should fall back to size descending
        #expect(sorted[0].url.lastPathComponent == "large.txt")
        #expect(sorted[1].url.lastPathComponent == "medium.txt")
        #expect(sorted[2].url.lastPathComponent == "small.txt")
    }
}
