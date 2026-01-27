import Foundation
import SwiftUI

/// View model for managing cleanup history display
@MainActor
@Observable
final class HistoryViewModel {

    // MARK: - State

    var sessions: [CleanupSession] = []
    var stats: SavingsStats?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let historyManager: HistoryManager

    // MARK: - Initialization

    init(historyManager: HistoryManager = HistoryManager()) {
        self.historyManager = historyManager
    }

    // MARK: - Data Loading

    /// Load all data (sessions and stats) from history manager
    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let sessionsTask = historyManager.loadSessions()
            async let statsTask = historyManager.loadStats()

            sessions = try await sessionsTask
            stats = try await statsTask
        } catch {
            errorMessage = "Failed to load history: \(error.localizedDescription)"
            sessions = []
            stats = SavingsStats.empty
        }

        isLoading = false
    }

    /// Load sessions from history manager
    func loadSessions() async {
        do {
            sessions = try await historyManager.loadSessions()
        } catch {
            errorMessage = "Failed to load sessions: \(error.localizedDescription)"
            sessions = []
        }
    }

    /// Load stats from history manager
    func loadStats() async {
        do {
            stats = try await historyManager.loadStats()
        } catch {
            errorMessage = "Failed to load stats: \(error.localizedDescription)"
            stats = SavingsStats.empty
        }
    }

    /// Refresh all data
    func refresh() async {
        await loadData()
    }

    // MARK: - Session Management

    /// Delete a specific session from history
    func deleteSession(_ session: CleanupSession) async {
        do {
            try await historyManager.deleteSession(session)
            // Reload to get updated data
            await loadData()
        } catch {
            errorMessage = "Failed to delete session: \(error.localizedDescription)"
        }
    }

    /// Clear all history
    func clearHistory() async {
        do {
            try await historyManager.clearHistory()
            sessions = []
            stats = SavingsStats.empty
        } catch {
            errorMessage = "Failed to clear history: \(error.localizedDescription)"
        }
    }

    // MARK: - Formatting Helpers

    func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func formatAbsoluteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func formatBytes(_ bytes: Int64) -> String {
        ByteFormatter.format(bytes)
    }
}

// MARK: - Preview Helpers

extension HistoryViewModel {
    static var preview: HistoryViewModel {
        let viewModel = HistoryViewModel()
        viewModel.sessions = MockDataProvider.generatePreviewSessions(count: 5)
        viewModel.stats = MockDataProvider.generatePreviewStats()
        return viewModel
    }

    static var empty: HistoryViewModel {
        let viewModel = HistoryViewModel()
        viewModel.sessions = []
        viewModel.stats = SavingsStats.empty
        return viewModel
    }
}
