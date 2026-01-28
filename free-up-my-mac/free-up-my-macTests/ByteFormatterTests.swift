import Testing
import Foundation
@testable import free_up_my_mac

@Suite("ByteFormatter Tests")
struct ByteFormatterTests {

    // MARK: - format(_ bytes: Int64) Tests

    @Test("Format 0 bytes")
    func testFormat_ZeroBytes() {
        let result = ByteFormatter.format(Int64(0))
        // ByteCountFormatter may return "Zero KB" or "0 bytes" depending on locale
        #expect(result.contains("0") || result.lowercased().contains("zero"))
    }

    @Test("Format bytes less than 1KB")
    func testFormat_BytesLessThanKB() {
        let result = ByteFormatter.format(Int64(500))
        #expect(result == "500 bytes")
    }

    @Test("Format exactly 1KB")
    func testFormat_ExactlyOneKB() {
        let result = ByteFormatter.format(Int64(1024))
        #expect(result == "1 KB")
    }

    @Test("Format 1MB")
    func testFormat_OneMB() {
        let result = ByteFormatter.format(Int64(1024 * 1024))
        #expect(result == "1 MB")
    }

    @Test("Format 1GB")
    func testFormat_OneGB() {
        let result = ByteFormatter.format(Int64(1024 * 1024 * 1024))
        #expect(result.contains("GB") || result.contains("gigabyte"))
    }

    @Test("Format 1TB")
    func testFormat_OneTB() {
        let result = ByteFormatter.format(Int64(1024) * 1024 * 1024 * 1024)
        #expect(result.contains("TB") || result.contains("terabyte"))
    }

    @Test("Format mixed size (1.5 MB)")
    func testFormat_MixedSize() {
        let bytes = Int64(1024 * 1024 + 512 * 1024) // 1.5 MB
        let result = ByteFormatter.format(bytes)
        #expect(result.contains("MB"))
    }

    // MARK: - format(_ bytes: Int) Tests

    @Test("Format Int overload works correctly")
    func testFormat_IntOverload() {
        let result = ByteFormatter.format(1024)
        #expect(result == "1 KB")
    }

    @Test("Format Int overload matches Int64 result")
    func testFormat_IntOverloadMatchesInt64() {
        let intResult = ByteFormatter.format(2048)
        let int64Result = ByteFormatter.format(Int64(2048))
        #expect(intResult == int64Result)
    }

    // MARK: - formatCompact Tests

    @Test("Format compact for 0 bytes")
    func testFormatCompact_ZeroBytes() {
        let result = ByteFormatter.formatCompact(Int64(0))
        // ByteCountFormatter may return "Zero KB" or "0 bytes" depending on locale
        #expect(result.contains("0") || result.lowercased().contains("zero"))
    }

    @Test("Format compact for KB")
    func testFormatCompact_KB() {
        let result = ByteFormatter.formatCompact(Int64(1024))
        #expect(result.contains("KB"))
    }

    @Test("Format compact for MB")
    func testFormatCompact_MB() {
        let result = ByteFormatter.formatCompact(Int64(1024 * 1024))
        #expect(result.contains("MB"))
    }

    @Test("Format compact for GB")
    func testFormatCompact_GB() {
        let result = ByteFormatter.formatCompact(Int64(1024 * 1024 * 1024))
        #expect(result.contains("GB"))
    }

    // MARK: - formatWithPrecision Tests

    @Test("Format with default precision (2 decimals)")
    func testFormatWithPrecision_Default() {
        let bytes = Int64(1536 * 1024) // 1.5 MB
        let result = ByteFormatter.formatWithPrecision(bytes)
        #expect(result == "1.50 MB")
    }

    @Test("Format with custom precision (1 decimal)")
    func testFormatWithPrecision_OneDecimal() {
        let bytes = Int64(1536 * 1024) // 1.5 MB
        let result = ByteFormatter.formatWithPrecision(bytes, decimals: 1)
        #expect(result == "1.5 MB")
    }

    @Test("Format with precision for bytes (no decimals)")
    func testFormatWithPrecision_Bytes() {
        let bytes = Int64(500)
        let result = ByteFormatter.formatWithPrecision(bytes)
        #expect(result == "500 B")
    }

    @Test("Format with precision for zero")
    func testFormatWithPrecision_Zero() {
        let result = ByteFormatter.formatWithPrecision(Int64(0))
        #expect(result == "0 B")
    }

    @Test("Format with precision for large values")
    func testFormatWithPrecision_LargeValue() {
        let bytes = Int64(1024) * 1024 * 1024 * 2 // 2 GB
        let result = ByteFormatter.formatWithPrecision(bytes)
        #expect(result == "2.00 GB")
    }

    @Test("Format with precision 3 decimals")
    func testFormatWithPrecision_ThreeDecimals() {
        let bytes = Int64(1234 * 1024) // ~1.205 MB
        let result = ByteFormatter.formatWithPrecision(bytes, decimals: 3)
        #expect(result.contains("MB"))
        #expect(result.contains("."))
    }

    @Test("Format with precision for TB")
    func testFormatWithPrecision_TB() {
        let bytes = Int64(1024) * 1024 * 1024 * 1024 // 1 TB
        let result = ByteFormatter.formatWithPrecision(bytes)
        #expect(result == "1.00 TB")
    }
}
