import Foundation

/// Manages persistent storage of cleanup history using JSON file storage
actor HistoryManager {

    // MARK: - History File Structure

    /// Internal struct matching the JSON schema for the history file
    private struct HistoryFile: Codable, Sendable {
        var totalSpaceSaved: Int64
        var totalFilesDeleted: Int
        var totalSessions: Int
        var sessions: [CleanupSession]

        static let empty = HistoryFile(
            totalSpaceSaved: 0,
            totalFilesDeleted: 0,
            totalSessions: 0,
            sessions: []
        )
    }

    // MARK: - Properties

    private let fileManager: FileManager
    private let historyFileURL: URL

    /// Cached history to avoid repeated disk reads
    private var cachedHistory: HistoryFile?

    // MARK: - Initialization

    /// Initialize with default file location at ~/Library/Application Support/FreeUpMyMac/history.json
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.historyFileURL = Self.defaultHistoryFileURL(fileManager: fileManager)
    }

    /// Initialize with custom file URL (for testing)
    init(historyFileURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.historyFileURL = historyFileURL
    }

    /// Returns the default history file URL
    private static func defaultHistoryFileURL(fileManager: FileManager) -> URL {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportURL.appendingPathComponent("FreeUpMyMac")
        return appDir.appendingPathComponent("history.json")
    }

    // MARK: - Public API

    /// Save a new cleanup session to history
    func saveSession(_ session: CleanupSession) async throws {
        var history = try await loadHistoryFile()

        // Insert at front (newest first)
        history.sessions.insert(session, at: 0)

        // Update totals
        history.totalFilesDeleted += session.filesDeleted
        history.totalSpaceSaved += session.bytesRecovered
        history.totalSessions += 1

        try await writeHistoryFile(history)
    }

    /// Load all sessions from history
    func loadSessions() async throws -> [CleanupSession] {
        let history = try await loadHistoryFile()
        return history.sessions
    }

    /// Load cumulative savings stats
    func loadStats() async throws -> SavingsStats {
        let history = try await loadHistoryFile()
        return SavingsStats(
            totalFilesDeleted: history.totalFilesDeleted,
            totalBytesRecovered: history.totalSpaceSaved,
            totalSessionsCompleted: history.totalSessions
        )
    }

    /// Delete a specific session from history
    func deleteSession(_ session: CleanupSession) async throws {
        var history = try await loadHistoryFile()

        // Find and remove the session
        if let index = history.sessions.firstIndex(where: { $0.id == session.id }) {
            let removedSession = history.sessions.remove(at: index)

            // Update totals
            history.totalFilesDeleted -= removedSession.filesDeleted
            history.totalSpaceSaved -= removedSession.bytesRecovered
            history.totalSessions -= 1

            // Ensure totals don't go negative
            history.totalFilesDeleted = max(0, history.totalFilesDeleted)
            history.totalSpaceSaved = max(0, history.totalSpaceSaved)
            history.totalSessions = max(0, history.totalSessions)

            try await writeHistoryFile(history)
        }
    }

    /// Clear all history
    func clearHistory() async throws {
        try await writeHistoryFile(.empty)
    }

    /// Invalidate the in-memory cache, forcing next load to read from disk
    /// Use this when data may have been modified by another instance
    func invalidateCache() {
        cachedHistory = nil
    }

    // MARK: - Private Helpers

    /// Load history file from disk (or return empty if doesn't exist)
    private func loadHistoryFile() async throws -> HistoryFile {
        // Return cached if available
        if let cached = cachedHistory {
            return cached
        }

        // Check if file exists
        guard fileManager.fileExists(atPath: historyFileURL.path) else {
            return .empty
        }

        // Read and decode
        let data = try Data(contentsOf: historyFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let history = try decoder.decode(HistoryFile.self, from: data)
        cachedHistory = history
        return history
    }

    /// Write history file to disk
    private func writeHistoryFile(_ history: HistoryFile) async throws {
        // Ensure parent directory exists
        let parentDir = historyFileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // Encode and write
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(history)
        try data.write(to: historyFileURL, options: .atomic)

        // Update cache
        cachedHistory = history
    }
}
