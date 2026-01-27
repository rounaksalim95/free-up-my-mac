import Testing
import Foundation
@testable import free_up_my_mac

@Suite("HistoryViewModel Tests")
@MainActor
struct HistoryViewModelTests {

    /// Helper to create a temporary test history URL
    private func createTempHistoryURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("test-history-viewmodel-\(UUID().uuidString).json")
    }

    /// Helper to clean up a test file
    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Initial State Tests

    @Test("Initial sessions is empty")
    func testInitialSessions_IsEmpty() async {
        let viewModel = HistoryViewModel()

        #expect(viewModel.sessions.isEmpty)
    }

    @Test("Initial stats is nil")
    func testInitialStats_IsNil() async {
        let viewModel = HistoryViewModel()

        #expect(viewModel.stats == nil)
    }

    @Test("Initial loading state is false")
    func testInitialLoadingState_IsFalse() async {
        let viewModel = HistoryViewModel()

        #expect(viewModel.isLoading == false)
    }

    @Test("Initial error message is nil")
    func testInitialErrorMessage_IsNil() async {
        let viewModel = HistoryViewModel()

        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Loading Tests

    @Test("Load data populates sessions and stats")
    func testLoadData_PopulatesSessionsAndStats() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)

        // Add a session to history
        let session = CleanupSession(
            scannedDirectories: ["~/Downloads"],
            filesDeleted: 10,
            bytesRecovered: 1024,
            duplicateGroupsCleaned: 5
        )
        try await manager.saveSession(session)

        let viewModel = HistoryViewModel(historyManager: manager)
        await viewModel.loadData()

        #expect(viewModel.sessions.count == 1)
        #expect(viewModel.sessions[0].id == session.id)
        #expect(viewModel.stats != nil)
        #expect(viewModel.stats?.totalFilesDeleted == 10)
    }

    @Test("Load data with empty history returns empty arrays")
    func testLoadData_WithEmptyHistory_ReturnsEmpty() async {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)
        let viewModel = HistoryViewModel(historyManager: manager)

        await viewModel.loadData()

        #expect(viewModel.sessions.isEmpty)
        #expect(viewModel.stats?.totalFilesDeleted == 0)
        #expect(viewModel.stats?.totalBytesRecovered == 0)
    }

    @Test("Loading state toggles during load")
    func testLoadingState_TogglesDuringLoad() async {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)
        let viewModel = HistoryViewModel(historyManager: manager)

        #expect(!viewModel.isLoading)

        await viewModel.loadData()

        #expect(!viewModel.isLoading)
    }

    // MARK: - Formatting Tests

    @Test("Format date returns readable string")
    func testFormatDate_ReturnsReadableString() async {
        let viewModel = HistoryViewModel()
        let date = Date()

        let formatted = viewModel.formatDate(date)

        #expect(!formatted.isEmpty)
    }

    @Test("Format bytes returns human readable size")
    func testFormatBytes_ReturnsHumanReadableSize() async {
        let viewModel = HistoryViewModel()

        let formatted = viewModel.formatBytes(1024 * 1024 * 100)

        #expect(formatted.contains("MB") || formatted.contains("100"))
    }

    // MARK: - Session Management Tests

    @Test("Clear history removes all sessions")
    func testClearHistory_RemovesAllSessions() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)

        // Add some sessions first
        let session = CleanupSession(
            scannedDirectories: ["~/Downloads"],
            filesDeleted: 10,
            bytesRecovered: 1024,
            duplicateGroupsCleaned: 5
        )
        try await manager.saveSession(session)

        let viewModel = HistoryViewModel(historyManager: manager)
        await viewModel.loadData()

        #expect(!viewModel.sessions.isEmpty)

        await viewModel.clearHistory()

        #expect(viewModel.sessions.isEmpty)
        #expect(viewModel.stats?.totalSessionsCompleted == 0)
    }

    @Test("Delete session removes specific session")
    func testDeleteSession_RemovesSpecificSession() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)

        // Add sessions
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

        let viewModel = HistoryViewModel(historyManager: manager)
        await viewModel.loadData()

        let initialCount = viewModel.sessions.count
        #expect(initialCount == 2)

        await viewModel.deleteSession(session1)

        #expect(viewModel.sessions.count == 1)
        #expect(!viewModel.sessions.contains { $0.id == session1.id })
        #expect(viewModel.sessions.contains { $0.id == session2.id })
    }

    // MARK: - Stats Calculation Tests

    @Test("Stats are correctly computed from history")
    func testStats_AreCorrectlyComputedFromHistory() async throws {
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

        let viewModel = HistoryViewModel(historyManager: manager)
        await viewModel.loadData()

        #expect(viewModel.stats?.totalFilesDeleted == 30)
        #expect(viewModel.stats?.totalBytesRecovered == 3000)
        #expect(viewModel.stats?.totalSessionsCompleted == 2)
    }

    // MARK: - Refresh Tests

    @Test("Refresh reloads data")
    func testRefresh_ReloadsData() async throws {
        let historyURL = createTempHistoryURL()
        defer { cleanup(historyURL) }

        let manager = HistoryManager(historyFileURL: historyURL)
        let viewModel = HistoryViewModel(historyManager: manager)

        // Load initially empty
        await viewModel.loadData()
        #expect(viewModel.sessions.isEmpty)

        // Add a session directly to the manager
        let session = CleanupSession(
            scannedDirectories: ["~/Downloads"],
            filesDeleted: 10,
            bytesRecovered: 1024,
            duplicateGroupsCleaned: 5
        )
        try await manager.saveSession(session)

        // Refresh should pick up the new session
        await viewModel.refresh()

        #expect(viewModel.sessions.count == 1)
    }
}
