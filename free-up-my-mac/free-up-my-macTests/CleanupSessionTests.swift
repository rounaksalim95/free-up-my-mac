import Testing
import Foundation
@testable import free_up_my_mac

@Suite("CleanupSession Tests")
struct CleanupSessionTests {

    // MARK: - Initialization Tests

    @Test("Initialize with single directory")
    func testInitializeWithSingleDirectory() async {
        let session = CleanupSession(
            scannedDirectory: "/Users/test/Documents",
            filesDeleted: 10,
            bytesRecovered: 1024 * 1024,
            duplicateGroupsCleaned: 3
        )

        #expect(session.scannedDirectory == "/Users/test/Documents")
        #expect(session.scannedDirectories == ["/Users/test/Documents"])
        #expect(session.filesDeleted == 10)
        #expect(session.bytesRecovered == 1024 * 1024)
        #expect(session.duplicateGroupsCleaned == 3)
        #expect(session.errors.isEmpty)
    }

    @Test("Initialize with multiple directories")
    func testInitializeWithMultipleDirectories() async {
        let session = CleanupSession(
            scannedDirectories: ["/Users/test/Documents", "/Users/test/Downloads"],
            filesDeleted: 15,
            bytesRecovered: 2048 * 1024,
            duplicateGroupsCleaned: 5
        )

        #expect(session.scannedDirectories == ["/Users/test/Documents", "/Users/test/Downloads"])
        #expect(session.scannedDirectory == "/Users/test/Documents, /Users/test/Downloads")
        #expect(session.filesDeleted == 15)
        #expect(session.bytesRecovered == 2048 * 1024)
    }

    @Test("Computed scannedDirectory joins multiple directories correctly")
    func testComputedScannedDirectory_JoinsDirectories() async {
        let session = CleanupSession(
            scannedDirectories: ["~/Downloads", "~/Documents", "~/Desktop"],
            filesDeleted: 20,
            bytesRecovered: 1024,
            duplicateGroupsCleaned: 2
        )

        #expect(session.scannedDirectory == "~/Downloads, ~/Documents, ~/Desktop")
    }

    @Test("Computed scannedDirectory with single directory returns just that directory")
    func testComputedScannedDirectory_SingleDirectory() async {
        let session = CleanupSession(
            scannedDirectories: ["/Users/test/Documents"],
            filesDeleted: 5,
            bytesRecovered: 512,
            duplicateGroupsCleaned: 1
        )

        #expect(session.scannedDirectory == "/Users/test/Documents")
    }

    // MARK: - JSON Encoding Tests

    @Test("JSON encoding produces correct schema")
    func testJSONEncoding_ProducesCorrectSchema() async throws {
        let sessionId = UUID()
        let sessionDate = Date(timeIntervalSince1970: 1705923000) // Fixed date for testing

        let session = CleanupSession(
            id: sessionId,
            date: sessionDate,
            scannedDirectories: ["~/Downloads", "~/Documents"],
            filesDeleted: 45,
            bytesRecovered: 2254857830,
            duplicateGroupsCleaned: 10,
            errors: []
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        let data = try encoder.encode(session)
        let jsonString = String(data: data, encoding: .utf8)!

        // Verify JSON uses correct field names
        #expect(jsonString.contains("\"spaceSaved\":2254857830"))
        #expect(jsonString.contains("\"filesDeleted\":45"))
        // Note: JSONEncoder may escape forward slashes as \/ in paths
        #expect(jsonString.contains("\"scannedDirectories\":"))
        #expect(jsonString.contains("Downloads"))
        #expect(jsonString.contains("Documents"))
        #expect(jsonString.contains("\"id\":"))
        #expect(jsonString.contains("\"date\":"))

        // Should NOT contain bytesRecovered (we use spaceSaved in JSON)
        #expect(!jsonString.contains("bytesRecovered"))
        // Should NOT contain scannedDirectory (singular) as a key
        #expect(!jsonString.contains("\"scannedDirectory\":"))
    }

    @Test("JSON decoding handles schema format")
    func testJSONDecoding_HandlesSchemaFormat() async throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "date": "2025-01-22T10:30:00Z",
            "filesDeleted": 45,
            "spaceSaved": 2254857830,
            "scannedDirectories": ["~/Downloads", "~/Documents"],
            "duplicateGroupsCleaned": 10,
            "errors": []
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = json.data(using: .utf8)!
        let session = try decoder.decode(CleanupSession.self, from: data)

        #expect(session.id.uuidString == "550E8400-E29B-41D4-A716-446655440000")
        #expect(session.filesDeleted == 45)
        #expect(session.bytesRecovered == 2254857830)
        #expect(session.scannedDirectories == ["~/Downloads", "~/Documents"])
        #expect(session.duplicateGroupsCleaned == 10)
        #expect(session.errors.isEmpty)
    }

    @Test("Round-trip encoding and decoding preserves data")
    func testRoundTrip_PreservesData() async throws {
        let original = CleanupSession(
            scannedDirectories: ["/Users/test/Documents", "/Users/test/Downloads"],
            filesDeleted: 100,
            bytesRecovered: 5000000000,
            duplicateGroupsCleaned: 25,
            errors: ["Error 1", "Error 2"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(CleanupSession.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.filesDeleted == original.filesDeleted)
        #expect(decoded.bytesRecovered == original.bytesRecovered)
        #expect(decoded.scannedDirectories == original.scannedDirectories)
        #expect(decoded.duplicateGroupsCleaned == original.duplicateGroupsCleaned)
        #expect(decoded.errors == original.errors)
    }

    // MARK: - Computed Property Tests

    @Test("wasSuccessful returns true for successful session")
    func testWasSuccessful_ReturnsTrue_ForSuccessfulSession() async {
        let session = CleanupSession(
            scannedDirectories: ["/test"],
            filesDeleted: 10,
            bytesRecovered: 1024,
            duplicateGroupsCleaned: 5
        )

        #expect(session.wasSuccessful == true)
    }

    @Test("wasSuccessful returns false when errors exist")
    func testWasSuccessful_ReturnsFalse_WhenErrorsExist() async {
        let session = CleanupSession(
            scannedDirectories: ["/test"],
            filesDeleted: 10,
            bytesRecovered: 1024,
            duplicateGroupsCleaned: 5,
            errors: ["Some error"]
        )

        #expect(session.wasSuccessful == false)
    }

    @Test("wasSuccessful returns false when no files deleted")
    func testWasSuccessful_ReturnsFalse_WhenNoFilesDeleted() async {
        let session = CleanupSession(
            scannedDirectories: ["/test"],
            filesDeleted: 0,
            bytesRecovered: 0,
            duplicateGroupsCleaned: 0
        )

        #expect(session.wasSuccessful == false)
    }
}

// MARK: - SavingsStats Tests

@Suite("SavingsStats Tests")
struct SavingsStatsTests {

    @Test("Empty stats has zero values")
    func testEmptyStats_HasZeroValues() async {
        let stats = SavingsStats.empty

        #expect(stats.totalFilesDeleted == 0)
        #expect(stats.totalBytesRecovered == 0)
        #expect(stats.totalSessionsCompleted == 0)
    }

    @Test("Add session updates stats correctly")
    func testAddSession_UpdatesStatsCorrectly() async {
        var stats = SavingsStats.empty

        let session = CleanupSession(
            scannedDirectories: ["/test"],
            filesDeleted: 10,
            bytesRecovered: 1024 * 1024,
            duplicateGroupsCleaned: 5
        )

        stats.add(session)

        #expect(stats.totalFilesDeleted == 10)
        #expect(stats.totalBytesRecovered == 1024 * 1024)
        #expect(stats.totalSessionsCompleted == 1)
    }

    @Test("Add multiple sessions accumulates correctly")
    func testAddMultipleSessions_AccumulatesCorrectly() async {
        var stats = SavingsStats.empty

        let session1 = CleanupSession(
            scannedDirectories: ["/test1"],
            filesDeleted: 10,
            bytesRecovered: 1000,
            duplicateGroupsCleaned: 5
        )

        let session2 = CleanupSession(
            scannedDirectories: ["/test2"],
            filesDeleted: 20,
            bytesRecovered: 2000,
            duplicateGroupsCleaned: 8
        )

        stats.add(session1)
        stats.add(session2)

        #expect(stats.totalFilesDeleted == 30)
        #expect(stats.totalBytesRecovered == 3000)
        #expect(stats.totalSessionsCompleted == 2)
    }
}
