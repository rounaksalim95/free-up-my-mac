import Foundation

struct ScannedFile: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let size: Int64
    let creationDate: Date?
    let modificationDate: Date?
    var partialHash: String?
    var fullHash: String?

    nonisolated init(
        id: UUID = UUID(),
        url: URL,
        size: Int64,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        partialHash: String? = nil,
        fullHash: String? = nil
    ) {
        self.id = id
        self.url = url
        self.size = size
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.partialHash = partialHash
        self.fullHash = fullHash
    }

    var fileName: String {
        url.lastPathComponent
    }

    var directoryPath: String {
        url.deletingLastPathComponent().path
    }

    var fileExtension: String {
        url.pathExtension.lowercased()
    }
}
