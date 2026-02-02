import Foundation

/// Represents the type of cleanup operation performed
enum CleanupType: String, Sendable, Codable, CaseIterable {
    case duplicates
    case largeFiles

    var displayName: String {
        switch self {
        case .duplicates:
            return "Duplicates"
        case .largeFiles:
            return "Large Files"
        }
    }

    var iconName: String {
        switch self {
        case .duplicates:
            return "doc.on.doc"
        case .largeFiles:
            return "externaldrive"
        }
    }
}

struct SavingsStats: Sendable, Codable {
    var totalFilesDeleted: Int
    var totalBytesRecovered: Int64
    var totalSessionsCompleted: Int

    init(
        totalFilesDeleted: Int = 0,
        totalBytesRecovered: Int64 = 0,
        totalSessionsCompleted: Int = 0
    ) {
        self.totalFilesDeleted = totalFilesDeleted
        self.totalBytesRecovered = totalBytesRecovered
        self.totalSessionsCompleted = totalSessionsCompleted
    }

    mutating func add(_ session: CleanupSession) {
        totalFilesDeleted += session.filesDeleted
        totalBytesRecovered += session.bytesRecovered
        totalSessionsCompleted += 1
    }

    static let empty = SavingsStats()
}

struct CleanupSession: Identifiable, Sendable, Codable {
    let id: UUID
    let date: Date
    let scannedDirectories: [String]
    let filesDeleted: Int
    let bytesRecovered: Int64
    let duplicateGroupsCleaned: Int
    let errors: [String]
    let cleanupType: CleanupType

    /// Computed property for backwards compatibility with UI that expects a single string
    var scannedDirectory: String {
        scannedDirectories.joined(separator: ", ")
    }

    /// CodingKeys to map JSON schema field names to Swift property names
    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case scannedDirectories
        case filesDeleted
        case bytesRecovered = "spaceSaved"  // JSON uses spaceSaved, we use bytesRecovered
        case duplicateGroupsCleaned
        case errors
        case cleanupType
    }

    /// Custom decoder for backwards compatibility with existing history entries
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        scannedDirectories = try container.decode([String].self, forKey: .scannedDirectories)
        filesDeleted = try container.decode(Int.self, forKey: .filesDeleted)
        bytesRecovered = try container.decode(Int64.self, forKey: .bytesRecovered)
        duplicateGroupsCleaned = try container.decode(Int.self, forKey: .duplicateGroupsCleaned)
        errors = try container.decode([String].self, forKey: .errors)
        // Default to .duplicates for existing history entries that don't have cleanupType
        cleanupType = try container.decodeIfPresent(CleanupType.self, forKey: .cleanupType) ?? .duplicates
    }

    /// Initialize with multiple directories
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        scannedDirectories: [String],
        filesDeleted: Int,
        bytesRecovered: Int64,
        duplicateGroupsCleaned: Int,
        errors: [String] = [],
        cleanupType: CleanupType = .duplicates
    ) {
        self.id = id
        self.date = date
        self.scannedDirectories = scannedDirectories
        self.filesDeleted = filesDeleted
        self.bytesRecovered = bytesRecovered
        self.duplicateGroupsCleaned = duplicateGroupsCleaned
        self.errors = errors
        self.cleanupType = cleanupType
    }

    /// Convenience initializer for single directory (backwards compatibility)
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        scannedDirectory: String,
        filesDeleted: Int,
        bytesRecovered: Int64,
        duplicateGroupsCleaned: Int,
        errors: [String] = [],
        cleanupType: CleanupType = .duplicates
    ) {
        self.init(
            id: id,
            date: date,
            scannedDirectories: [scannedDirectory],
            filesDeleted: filesDeleted,
            bytesRecovered: bytesRecovered,
            duplicateGroupsCleaned: duplicateGroupsCleaned,
            errors: errors,
            cleanupType: cleanupType
        )
    }

    var wasSuccessful: Bool {
        errors.isEmpty && filesDeleted > 0
    }
}
