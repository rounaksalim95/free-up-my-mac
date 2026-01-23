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

    // MARK: - Initialization

    init() {
        loadSessions()
        loadStats()
    }

    // MARK: - Data Loading

    func loadSessions() {
        // Load from HistoryManager when implemented
        // For now, use empty or mock data for preview
        // sessions = [] // Will be populated when HistoryManager is implemented
    }

    func loadStats() {
        // Load from HistoryManager when implemented
        // For now, compute from sessions or use empty stats
        stats = computeStatsFromSessions()
    }

    func refresh() {
        loadSessions()
        loadStats()
    }

    // MARK: - Session Management

    func deleteSession(_ session: CleanupSession) {
        sessions.removeAll { $0.id == session.id }
        // When HistoryManager is implemented:
        // Task { await historyManager.deleteSession(session.id) }

        // Recompute stats
        stats = computeStatsFromSessions()
    }

    func clearHistory() {
        sessions.removeAll()
        stats = SavingsStats.empty
        // When HistoryManager is implemented:
        // Task { await historyManager.clearHistory() }
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

    // MARK: - Private Helpers

    private func computeStatsFromSessions() -> SavingsStats {
        var stats = SavingsStats.empty

        for session in sessions {
            stats.add(session)
        }

        return stats
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
