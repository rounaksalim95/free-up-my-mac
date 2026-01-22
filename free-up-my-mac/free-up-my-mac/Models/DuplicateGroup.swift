import Foundation

struct DuplicateGroup: Identifiable, Hashable, Sendable {
    let id: UUID
    let hash: String
    let size: Int64
    var files: [ScannedFile]

    init(
        id: UUID = UUID(),
        hash: String,
        size: Int64,
        files: [ScannedFile]
    ) {
        self.id = id
        self.hash = hash
        self.size = size
        self.files = files
    }

    var duplicateCount: Int {
        files.count
    }

    var potentialSavings: Int64 {
        guard files.count > 1 else { return 0 }
        return size * Int64(files.count - 1)
    }

    var totalSize: Int64 {
        size * Int64(files.count)
    }

    var fileExtension: String {
        files.first?.fileExtension ?? ""
    }

    var fileName: String {
        files.first?.fileName ?? "Unknown"
    }
}
