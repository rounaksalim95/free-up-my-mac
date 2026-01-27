import Foundation

/// Represents a file that was skipped during scanning due to an error
struct SkippedFile: Sendable, Identifiable {
    let id: UUID
    let url: URL
    let reason: SkipReason

    init(id: UUID = UUID(), url: URL, reason: SkipReason) {
        self.id = id
        self.url = url
        self.reason = reason
    }

    /// The reason why a file was skipped during scanning
    enum SkipReason: Sendable {
        case permissionDenied
        case readError(String)
        case hashingFailed(String)

        var localizedDescription: String {
            switch self {
            case .permissionDenied:
                return "Permission denied"
            case .readError(let message):
                return "Read error: \(message)"
            case .hashingFailed(let message):
                return "Hashing failed: \(message)"
            }
        }
    }

    /// The file name for display
    var fileName: String {
        url.lastPathComponent
    }

    /// The directory path for display
    var directoryPath: String {
        url.deletingLastPathComponent().path
    }
}
