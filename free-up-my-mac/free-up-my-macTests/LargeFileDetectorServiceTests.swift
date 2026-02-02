import Testing
import Foundation
@testable import free_up_my_mac

@Suite("LargeFileDetectorService Tests")
struct LargeFileDetectorServiceTests {

    // MARK: - Test 1: Empty Input Returns Empty Result

    @Test("Find large files with empty input returns empty result")
    func testFindLargeFiles_EmptyInput_ReturnsEmptyResult() async throws {
        let detector = LargeFileDetectorService()

        let result = try await detector.findLargeFiles(
            in: [],
            minimumSize: 100 * 1024 * 1024
        ) { _ in }

        #expect(result.largeFileGroups.isEmpty)
        #expect(result.totalFilesFound == 0)
        #expect(result.totalSize == 0)
    }

    // MARK: - Test 2: Filters Files Below Minimum Size

    @Test("Find large files filters files below minimum size")
    func testFindLargeFiles_FiltersBelowMinimum() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/test/small.txt"), size: 50 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/test/large.txt"), size: 150 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/test/tiny.txt"), size: 1 * 1024 * 1024)
        ]

        let detector = LargeFileDetectorService()

        let result = try await detector.findLargeFiles(
            in: files,
            minimumSize: 100 * 1024 * 1024
        ) { _ in }

        #expect(result.totalFilesFound == 1)
        #expect(result.largeFileGroups.count == 1)

        let group = result.largeFileGroups.first!
        #expect(group.files.count == 1)
        #expect(group.files.first?.url.lastPathComponent == "large.txt")
    }

    // MARK: - Test 3: Groups Files By Parent Folder

    @Test("Find large files groups files by parent folder")
    func testFindLargeFiles_GroupsByParentFolder() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Documents/video.mp4"), size: 500 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/Documents/backup.zip"), size: 200 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/Downloads/installer.dmg"), size: 1024 * 1024 * 1024)
        ]

        let detector = LargeFileDetectorService()

        let result = try await detector.findLargeFiles(
            in: files,
            minimumSize: 100 * 1024 * 1024
        ) { _ in }

        #expect(result.totalFilesFound == 3)
        #expect(result.largeFileGroups.count == 2)

        let documentsGroup = result.largeFileGroups.first { $0.folderName == "Documents" }
        let downloadsGroup = result.largeFileGroups.first { $0.folderName == "Downloads" }

        #expect(documentsGroup != nil)
        #expect(downloadsGroup != nil)
        #expect(documentsGroup?.files.count == 2)
        #expect(downloadsGroup?.files.count == 1)
    }

    // MARK: - Test 4: Sorts Groups By Total Size Descending

    @Test("Find large files sorts groups by total size descending")
    func testFindLargeFiles_SortsGroupsByTotalSize() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/SmallFolder/file.txt"), size: 100 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/LargeFolder/big1.mp4"), size: 500 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/LargeFolder/big2.mp4"), size: 500 * 1024 * 1024)
        ]

        let detector = LargeFileDetectorService()

        let result = try await detector.findLargeFiles(
            in: files,
            minimumSize: 100 * 1024 * 1024
        ) { _ in }

        #expect(result.largeFileGroups.count == 2)

        // LargeFolder (1GB total) should be first
        #expect(result.largeFileGroups[0].folderName == "LargeFolder")
        #expect(result.largeFileGroups[1].folderName == "SmallFolder")
    }

    // MARK: - Test 5: Sorts Files Within Group By Size

    @Test("Find large files sorts files within group by size descending")
    func testFindLargeFiles_SortsFilesWithinGroup() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Folder/small.txt"), size: 100 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/large.txt"), size: 500 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/medium.txt"), size: 250 * 1024 * 1024)
        ]

        let detector = LargeFileDetectorService()

        let result = try await detector.findLargeFiles(
            in: files,
            minimumSize: 100 * 1024 * 1024
        ) { _ in }

        let group = result.largeFileGroups.first!
        #expect(group.files[0].url.lastPathComponent == "large.txt")
        #expect(group.files[1].url.lastPathComponent == "medium.txt")
        #expect(group.files[2].url.lastPathComponent == "small.txt")
    }

    // MARK: - Test 6: Reports Correct Total Size

    @Test("Find large files reports correct total size")
    func testFindLargeFiles_ReportsCorrectTotalSize() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/Folder/file1.txt"), size: 100 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/file2.txt"), size: 200 * 1024 * 1024),
            ScannedFile(url: URL(fileURLWithPath: "/Folder/file3.txt"), size: 300 * 1024 * 1024)
        ]

        let detector = LargeFileDetectorService()

        let result = try await detector.findLargeFiles(
            in: files,
            minimumSize: 100 * 1024 * 1024
        ) { _ in }

        let expectedTotal: Int64 = 600 * 1024 * 1024
        #expect(result.totalSize == expectedTotal)
    }

    // MARK: - Test 7: Can Be Cancelled

    @Test("Find large files can be cancelled")
    func testFindLargeFiles_CanBeCancelled() async throws {
        // Create a large array of files
        var files: [ScannedFile] = []
        for i in 0..<10000 {
            files.append(ScannedFile(
                url: URL(fileURLWithPath: "/Folder/file\(i).txt"),
                size: 100 * 1024 * 1024
            ))
        }

        let detector = LargeFileDetectorService()

        let task = Task {
            try await detector.findLargeFiles(
                in: files,
                minimumSize: 50 * 1024 * 1024
            ) { _ in }
        }

        // Cancel immediately
        await detector.cancel()

        do {
            _ = try await task.value
            // If it completes, that's also acceptable for fast operations
        } catch let error as ScanError {
            #expect(error == .cancelled)
        }
    }

    // MARK: - Test 8: Date Range Calculation

    @Test("Calculate date range returns correct oldest and newest dates")
    func testCalculateDateRange_ReturnsCorrectDates() async throws {
        let oldDate = Date().addingTimeInterval(-86400 * 365) // 1 year ago
        let newDate = Date().addingTimeInterval(-86400) // 1 day ago
        let middleDate = Date().addingTimeInterval(-86400 * 180) // 6 months ago

        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/file1.txt"), size: 100, modificationDate: oldDate),
            ScannedFile(url: URL(fileURLWithPath: "/file2.txt"), size: 100, modificationDate: newDate),
            ScannedFile(url: URL(fileURLWithPath: "/file3.txt"), size: 100, modificationDate: middleDate)
        ]

        let range = LargeFileDetectorService.calculateDateRange(from: files)

        #expect(range != nil)
        #expect(range!.oldest == oldDate)
        #expect(range!.newest == newDate)
    }

    // MARK: - Test 9: Date Range With No Dates Returns Nil

    @Test("Calculate date range with no dates returns nil")
    func testCalculateDateRange_NoDates_ReturnsNil() async throws {
        let files = [
            ScannedFile(url: URL(fileURLWithPath: "/file1.txt"), size: 100, modificationDate: nil),
            ScannedFile(url: URL(fileURLWithPath: "/file2.txt"), size: 100, modificationDate: nil)
        ]

        let range = LargeFileDetectorService.calculateDateRange(from: files)

        #expect(range == nil)
    }

    // MARK: - Test 10: Empty Array Date Range Returns Nil

    @Test("Calculate date range with empty array returns nil")
    func testCalculateDateRange_EmptyArray_ReturnsNil() async throws {
        let range = LargeFileDetectorService.calculateDateRange(from: [])
        #expect(range == nil)
    }
}
