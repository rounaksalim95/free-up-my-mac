import Foundation

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
    }

    /// Initialize with multiple directories
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        scannedDirectories: [String],
        filesDeleted: Int,
        bytesRecovered: Int64,
        duplicateGroupsCleaned: Int,
        errors: [String] = []
    ) {
        self.id = id
        self.date = date
        self.scannedDirectories = scannedDirectories
        self.filesDeleted = filesDeleted
        self.bytesRecovered = bytesRecovered
        self.duplicateGroupsCleaned = duplicateGroupsCleaned
        self.errors = errors
    }

    /// Convenience initializer for single directory (backwards compatibility)
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        scannedDirectory: String,
        filesDeleted: Int,
        bytesRecovered: Int64,
        duplicateGroupsCleaned: Int,
        errors: [String] = []
    ) {
        self.init(
            id: id,
            date: date,
            scannedDirectories: [scannedDirectory],
            filesDeleted: filesDeleted,
            bytesRecovered: bytesRecovered,
            duplicateGroupsCleaned: duplicateGroupsCleaned,
            errors: errors
        )
    }

    var wasSuccessful: Bool {
        errors.isEmpty && filesDeleted > 0
    }
}
