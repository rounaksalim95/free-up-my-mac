import Foundation

actor HistoryManager {
    private let userDefaults: UserDefaults
    private let historyKey = "cleanup_sessions"
    private let statsKey = "savings_stats"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func saveSession(_ session: CleanupSession) async {
        fatalError("Not yet implemented")
    }

    func loadSessions() async -> [CleanupSession] {
        fatalError("Not yet implemented")
    }

    func loadStats() async -> SavingsStats {
        fatalError("Not yet implemented")
    }

    func clearHistory() async {
        fatalError("Not yet implemented")
    }

    func deleteSession(_ session: CleanupSession) async {
        fatalError("Not yet implemented")
    }
}
