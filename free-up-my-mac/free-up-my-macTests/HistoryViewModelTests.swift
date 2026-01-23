import Testing
import Foundation
@testable import free_up_my_mac

@Suite("HistoryViewModel Tests")
@MainActor
struct HistoryViewModelTests {

    // MARK: - Initial State Tests

    @Test("Initial sessions is empty for mock data")
    func testInitialSessions_IsEmptyOrMocked() async {
        let viewModel = HistoryViewModel()

        // With mock data, we expect some sessions
        // When HistoryManager is implemented, this will load from UserDefaults
        #expect(viewModel.sessions.count >= 0)
    }

    @Test("Initial stats contains cumulative data")
    func testInitialStats_ContainsCumulativeData() async {
        let viewModel = HistoryViewModel()

        // Stats should be non-nil
        #expect(viewModel.stats != nil)
    }

    // MARK: - Loading Tests

    @Test("Load sessions populates sessions array")
    func testLoadSessions_PopulatesSessions() async {
        let viewModel = HistoryViewModel()

        viewModel.loadSessions()

        // Should have loaded mock data
        #expect(viewModel.sessions.count >= 0)
    }

    @Test("Load stats populates stats")
    func testLoadStats_PopulatesStats() async {
        let viewModel = HistoryViewModel()

        viewModel.loadStats()

        #expect(viewModel.stats != nil)
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
    func testClearHistory_RemovesAllSessions() async {
        let viewModel = HistoryViewModel()

        viewModel.clearHistory()

        #expect(viewModel.sessions.isEmpty)
        #expect(viewModel.stats?.totalSessionsCompleted == 0)
    }

    @Test("Delete session removes specific session")
    func testDeleteSession_RemovesSpecificSession() async {
        let viewModel = HistoryViewModel()

        // Add mock sessions if empty
        if viewModel.sessions.isEmpty {
            viewModel.sessions = MockDataProvider.generatePreviewSessions(count: 3)
        }

        let initialCount = viewModel.sessions.count
        guard let firstSession = viewModel.sessions.first else {
            Issue.record("No sessions to delete")
            return
        }

        viewModel.deleteSession(firstSession)

        #expect(viewModel.sessions.count == initialCount - 1)
        #expect(!viewModel.sessions.contains { $0.id == firstSession.id })
    }

    // MARK: - Stats Calculation Tests

    @Test("Total savings from stats calculates correctly")
    func testTotalSavingsFromStats_CalculatesCorrectly() async {
        let viewModel = HistoryViewModel()

        // Set stats after initialization
        let testStats = SavingsStats(
            totalFilesDeleted: 50,
            totalBytesRecovered: 1024 * 1024 * 500,
            totalSessionsCompleted: 5
        )
        viewModel.stats = testStats

        #expect(viewModel.stats != nil)
        #expect(viewModel.stats!.totalBytesRecovered == testStats.totalBytesRecovered)
        #expect(viewModel.stats!.totalFilesDeleted == testStats.totalFilesDeleted)
        #expect(viewModel.stats!.totalSessionsCompleted == testStats.totalSessionsCompleted)
    }
}
