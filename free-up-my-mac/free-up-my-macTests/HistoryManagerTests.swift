import Testing
import Foundation
@testable import free_up_my_mac

@Suite("HistoryManager Tests")
struct HistoryManagerTests {

    /// Helper to create a temporary test file URL
    private func createTempHistoryURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("test-history-\(UUID().uuidString).json")
    }

    /// Helper to clean up a test file
    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Save Session Tests

    @Test("Save session creates file with correct structure")
    func testSaveSession_CreatesFileWithCorrectStructure() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)

        let session = CleanupSession(
            scannedDirectories: ["~/Downloads"],
            filesDeleted: 10,
            bytesRecovered: 1024 * 1024,
            duplicateGroupsCleaned: 5
        )

        try await manager.saveSession(session)

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: historyURL.path))

        // Verify content structure
        let data = try Data(contentsOf: historyURL)

        // Parse as dictionary to check structure
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // JSON numbers can be Int or Int64, so use NSNumber comparison
        let totalSpaceSaved = (json["totalSpaceSaved"] as? NSNumber)?.int64Value
        let totalFilesDeleted = (json["totalFilesDeleted"] as? NSNumber)?.intValue
        let totalSessions = (json["totalSessions"] as? NSNumber)?.intValue
        let expectedBytes: Int64 = 1024 * 1024

        #expect(totalSpaceSaved == expectedBytes)
        #expect(totalFilesDeleted == 10)
        #expect(totalSessions == 1)
        #expect((json["sessions"] as? [[String: Any]])?.count == 1)
    }

    @Test("Save multiple sessions updates totals correctly")
    func testSaveMultipleSessions_UpdatesTotalsCorrectly() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)

        let session1 = CleanupSession(
            scannedDirectories: ["~/Downloads"],
            filesDeleted: 10,
            bytesRecovered: 1000,
            duplicateGroupsCleaned: 5
        )

        let session2 = CleanupSession(
            scannedDirectories: ["~/Documents"],
            filesDeleted: 20,
            bytesRecovered: 2000,
            duplicateGroupsCleaned: 8
        )

        try await manager.saveSession(session1)
        try await manager.saveSession(session2)

        let stats = try await manager.loadStats()

        #expect(stats.totalFilesDeleted == 30)
        #expect(stats.totalBytesRecovered == 3000)
        #expect(stats.totalSessionsCompleted == 2)
    }

    @Test("Saved sessions are in newest-first order")
    func testSavedSessions_AreInNewestFirstOrder() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)

        let session1 = CleanupSession(
            date: Date(timeIntervalSinceNow: -3600), // 1 hour ago
            scannedDirectories: ["~/First"],
            filesDeleted: 5,
            bytesRecovered: 500,
            duplicateGroupsCleaned: 2
        )

        let session2 = CleanupSession(
            date: Date(), // Now
            scannedDirectories: ["~/Second"],
            filesDeleted: 10,
            bytesRecovered: 1000,
            duplicateGroupsCleaned: 4
        )

        try await manager.saveSession(session1)
        try await manager.saveSession(session2)

        let sessions = try await manager.loadSessions()

        #expect(sessions.count == 2)
        #expect(sessions[0].scannedDirectories == ["~/Second"]) // Newest first
        #expect(sessions[1].scannedDirectories == ["~/First"])
    }

    // MARK: - Load Tests

    @Test("Load sessions returns empty when no file exists")
    func testLoadSessions_ReturnsEmptyWhenNoFileExists() async throws {
        let historyURL = createTempHistoryURL()
        // Don't create the file

        let manager = HistoryManager(historyFileURL: historyURL)

        let sessions = try await manager.loadSessions()

        #expect(sessions.isEmpty)
    }

    @Test("Load stats returns empty when no file exists")
    func testLoadStats_ReturnsEmptyWhenNoFileExists() async throws {
        let historyURL = createTempHistoryURL()
        // Don't create the file

        let manager = HistoryManager(historyFileURL: historyURL)

        let stats = try await manager.loadStats()

        #expect(stats.totalFilesDeleted == 0)
        #expect(stats.totalBytesRecovered == 0)
        #expect(stats.totalSessionsCompleted == 0)
    }

    @Test("Load sessions returns saved sessions")
    func testLoadSessions_ReturnsSavedSessions() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)

        let session = CleanupSession(
            scannedDirectories: ["~/Downloads", "~/Documents"],
            filesDeleted: 25,
            bytesRecovered: 5000000,
            duplicateGroupsCleaned: 12
        )

        try await manager.saveSession(session)

        let loadedSessions = try await manager.loadSessions()

        #expect(loadedSessions.count == 1)
        #expect(loadedSessions[0].id == session.id)
        #expect(loadedSessions[0].filesDeleted == 25)
        #expect(loadedSessions[0].bytesRecovered == 5000000)
        #expect(loadedSessions[0].scannedDirectories == ["~/Downloads", "~/Documents"])
    }

    // MARK: - Delete Session Tests

    @Test("Delete session removes specific session and updates totals")
    func testDeleteSession_RemovesSessionAndUpdatesTotals() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)

        let session1 = CleanupSession(
            scannedDirectories: ["~/First"],
            filesDeleted: 10,
            bytesRecovered: 1000,
            duplicateGroupsCleaned: 5
        )

        let session2 = CleanupSession(
            scannedDirectories: ["~/Second"],
            filesDeleted: 20,
            bytesRecovered: 2000,
            duplicateGroupsCleaned: 8
        )

        try await manager.saveSession(session1)
        try await manager.saveSession(session2)

        try await manager.deleteSession(session1)

        let sessions = try await manager.loadSessions()
        let stats = try await manager.loadStats()

        #expect(sessions.count == 1)
        #expect(sessions[0].id == session2.id)
        #expect(stats.totalFilesDeleted == 20)
        #expect(stats.totalBytesRecovered == 2000)
        #expect(stats.totalSessionsCompleted == 1)
    }

    @Test("Delete non-existent session does nothing")
    func testDeleteNonExistentSession_DoesNothing() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)

        let session1 = CleanupSession(
            scannedDirectories: ["~/First"],
            filesDeleted: 10,
            bytesRecovered: 1000,
            duplicateGroupsCleaned: 5
        )

        let nonExistentSession = CleanupSession(
            scannedDirectories: ["~/Fake"],
            filesDeleted: 100,
            bytesRecovered: 10000,
            duplicateGroupsCleaned: 50
        )

        try await manager.saveSession(session1)
        try await manager.deleteSession(nonExistentSession)

        let sessions = try await manager.loadSessions()

        #expect(sessions.count == 1)
        #expect(sessions[0].id == session1.id)
    }

    // MARK: - Clear History Tests

    @Test("Clear history creates empty history file")
    func testClearHistory_CreatesEmptyFile() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)

        // Add some sessions first
        let session = CleanupSession(
            scannedDirectories: ["~/Downloads"],
            filesDeleted: 10,
            bytesRecovered: 1000,
            duplicateGroupsCleaned: 5
        )

        try await manager.saveSession(session)
        try await manager.clearHistory()

        let sessions = try await manager.loadSessions()
        let stats = try await manager.loadStats()

        #expect(sessions.isEmpty)
        #expect(stats.totalFilesDeleted == 0)
        #expect(stats.totalBytesRecovered == 0)
        #expect(stats.totalSessionsCompleted == 0)
    }

    // MARK: - JSON Format Tests

    @Test("JSON format matches expected schema")
    func testJSONFormat_MatchesExpectedSchema() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)

        let fixedDate = Date(timeIntervalSince1970: 1705923000)
        let fixedId = UUID()

        let session = CleanupSession(
            id: fixedId,
            date: fixedDate,
            scannedDirectories: ["~/Downloads", "~/Documents"],
            filesDeleted: 45,
            bytesRecovered: 2254857830,
            duplicateGroupsCleaned: 10,
            errors: []
        )

        try await manager.saveSession(session)

        // Read raw JSON
        let data = try Data(contentsOf: historyURL)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Check root structure
        #expect(json["totalSpaceSaved"] != nil)
        #expect(json["totalFilesDeleted"] != nil)
        #expect(json["totalSessions"] != nil)
        #expect(json["sessions"] != nil)

        // Check session structure
        let sessions = json["sessions"] as! [[String: Any]]
        let firstSession = sessions[0]

        #expect(firstSession["id"] != nil)
        #expect(firstSession["date"] != nil)
        #expect(firstSession["filesDeleted"] != nil)
        #expect(firstSession["spaceSaved"] != nil)
        #expect(firstSession["scannedDirectories"] != nil)

        // Verify ISO8601 date format
        let dateString = firstSession["date"] as! String
        #expect(dateString.contains("T"))
        #expect(dateString.contains("Z") || dateString.contains("+") || dateString.contains("-"))
    }

    // MARK: - Directory Creation Tests

    @Test("Save creates parent directory if needed")
    func testSave_CreatesParentDirectoryIfNeeded() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let nestedURL = tempDir
            .appendingPathComponent("test-nested-\(UUID().uuidString)")
            .appendingPathComponent("subdir")
            .appendingPathComponent("history.json")

        defer {
            // Clean up the entire nested directory
            let parentDir = nestedURL.deletingLastPathComponent().deletingLastPathComponent()
            try? FileManager.default.removeItem(at: parentDir)
        }

        let manager = HistoryManager(historyFileURL: nestedURL)

        let session = CleanupSession(
            scannedDirectories: ["~/Downloads"],
            filesDeleted: 5,
            bytesRecovered: 500,
            duplicateGroupsCleaned: 2
        )

        try await manager.saveSession(session)

        #expect(FileManager.default.fileExists(atPath: nestedURL.path))
    }
}
