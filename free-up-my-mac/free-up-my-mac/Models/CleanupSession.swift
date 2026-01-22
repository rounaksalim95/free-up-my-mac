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
    let scannedDirectory: String
    let filesDeleted: Int
    let bytesRecovered: Int64
    let duplicateGroupsCleaned: Int
    let errors: [String]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        scannedDirectory: String,
        filesDeleted: Int,
        bytesRecovered: Int64,
        duplicateGroupsCleaned: Int,
        errors: [String] = []
    ) {
        self.id = id
        self.date = date
        self.scannedDirectory = scannedDirectory
        self.filesDeleted = filesDeleted
        self.bytesRecovered = bytesRecovered
        self.duplicateGroupsCleaned = duplicateGroupsCleaned
        self.errors = errors
    }

    var wasSuccessful: Bool {
        errors.isEmpty && filesDeleted > 0
    }
}
