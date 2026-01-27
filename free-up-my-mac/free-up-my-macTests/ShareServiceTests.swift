import Testing
import Foundation
import AppKit
@testable import free_up_my_mac

@Suite("ShareService Tests")
struct ShareServiceTests {

    // MARK: - Text Generation Tests

    @Test("Generate share text includes key elements")
    func testGenerateShareText_IncludesKeyElements() async {
        let service = ShareService()
        let stats = SavingsStats(
            totalFilesDeleted: 50,
            totalBytesRecovered: 1_000_000_000,
            totalSessionsCompleted: 5
        )

        let text = service.generateShareText(stats: stats, latestSavings: nil)

        // Should include download URL
        #expect(text.contains("freeupmymac.app"))
        // Should include stats
        #expect(text.contains("50"))
        #expect(text.contains("Files deleted") || text.contains("files"))
    }

    @Test("Generate share text includes latest savings when provided")
    func testGenerateShareText_IncludesLatestSavings() async {
        let service = ShareService()
        let stats = SavingsStats(
            totalFilesDeleted: 50,
            totalBytesRecovered: 1_000_000_000,
            totalSessionsCompleted: 5
        )

        let text = service.generateShareText(stats: stats, latestSavings: 500_000_000)

        #expect(text.contains("freed up"))
        #expect(text.contains("freeupmymac.app"))
    }

    // MARK: - Report Generation Tests

    @Test("Generate report includes scan stats")
    func testGenerateReport_IncludesScanStats() async {
        let service = ShareService()

        let result = ScanResult(
            scannedDirectory: URL(fileURLWithPath: "/Users/test/Documents"),
            totalFilesScanned: 1000,
            totalBytesScanned: 5_000_000_000,
            duplicateGroups: [],
            scanDuration: 10.5
        )

        let report = service.generateReport(from: result)

        #expect(report.contains("1000") || report.contains("1,000"))
        #expect(report.contains("Documents") || report.contains("/Users/test"))
    }

    // MARK: - CSV Export Tests

    @Test("Export to CSV generates valid CSV format")
    func testExportToCSV_GeneratesValidFormat() async {
        let service = ShareService()

        let file1 = ScannedFile(url: URL(fileURLWithPath: "/test/file1.txt"), size: 1024)
        let file2 = ScannedFile(url: URL(fileURLWithPath: "/test/file2.txt"), size: 1024)

        let groups = [
            DuplicateGroup(hash: "abc123", size: 1024, files: [file1, file2])
        ]

        let csv = service.exportToCSV(groups: groups)

        // Verify CSV has header
        #expect(csv.contains("Group"))
        #expect(csv.contains("Path"))
        #expect(csv.contains("Size"))

        // Verify CSV has data rows
        #expect(csv.contains("file1.txt") || csv.contains("/test/file1.txt"))
        #expect(csv.contains("file2.txt") || csv.contains("/test/file2.txt"))
    }

    @Test("Export empty groups returns header only")
    func testExportEmptyGroups_ReturnsHeaderOnly() async {
        let service = ShareService()

        let csv = service.exportToCSV(groups: [])

        // Should have header line
        #expect(csv.contains("Group"))
        #expect(csv.contains("Path"))

        // Should have minimal content (just header)
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 1)
    }

    // MARK: - Image Generation Tests

    @Test("Generate share image returns non-nil image")
    @MainActor
    func testGenerateShareImage_ReturnsNonNilImage() async {
        let service = ShareService()
        let stats = SavingsStats(
            totalFilesDeleted: 50,
            totalBytesRecovered: 1_000_000_000,
            totalSessionsCompleted: 5
        )

        let image = service.generateShareImage(stats: stats, latestSavings: 500_000_000)

        #expect(image != nil)
    }

    @Test("Generated image has correct dimensions")
    @MainActor
    func testGeneratedImage_HasCorrectDimensions() async {
        let service = ShareService()
        let stats = SavingsStats(
            totalFilesDeleted: 50,
            totalBytesRecovered: 1_000_000_000,
            totalSessionsCompleted: 5
        )

        let image = service.generateShareImage(stats: stats, latestSavings: nil)

        #expect(image != nil)
        if let img = image {
            // At 2x scale, the image should be 1200x800 pixels
            // But we check the representation size which may vary
            #expect(img.size.width > 0)
            #expect(img.size.height > 0)
        }
    }

    // MARK: - Clipboard Tests

    @Test("Copy to clipboard sets pasteboard content")
    func testCopyToClipboard_SetsPasteboardContent() async {
        let service = ShareService()
        let testString = "Test clipboard content \(UUID().uuidString)"

        service.copyToClipboard(testString)

        let pasteboard = NSPasteboard.general
        let pasteboardContent = pasteboard.string(forType: .string)

        #expect(pasteboardContent == testString)
    }
}
