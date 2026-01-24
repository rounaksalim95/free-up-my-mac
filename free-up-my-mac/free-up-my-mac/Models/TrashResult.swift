import Foundation

/// Result of a batch trash operation
struct TrashResult: Sendable {
    let trashedCount: Int
    let bytesFreed: Int64
    let failedFiles: [FailedFile]

    /// Whether all files were successfully trashed
    var wasCompleteSuccess: Bool {
        failedFiles.isEmpty && trashedCount > 0
    }

    /// Whether some files were trashed but others failed
    var wasPartialSuccess: Bool {
        !failedFiles.isEmpty && trashedCount > 0
    }

    /// Whether no files were trashed at all
    var wasCompleteFailure: Bool {
        trashedCount == 0 && !failedFiles.isEmpty
    }

    /// Whether the operation was empty (no files selected)
    var wasEmpty: Bool {
        trashedCount == 0 && failedFiles.isEmpty
    }
}

/// A file that failed to be trashed
struct FailedFile: Sendable {
    let url: URL
    let reason: FailureReason

    enum FailureReason: Sendable {
        case notFound
        case permissionDenied
        case unknown(String)

        var localizedDescription: String {
            switch self {
            case .notFound:
                return "File not found"
            case .permissionDenied:
                return "Permission denied"
            case .unknown(let message):
                return message
            }
        }
    }
}
