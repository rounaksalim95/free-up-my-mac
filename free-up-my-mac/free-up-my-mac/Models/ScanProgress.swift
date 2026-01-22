import Foundation

enum ScanPhase: String, Sendable {
    case idle = "Idle"
    case enumerating = "Discovering files"
    case groupingBySize = "Grouping by size"
    case computingPartialHashes = "Computing partial hashes"
    case computingFullHashes = "Computing full hashes"
    case findingDuplicates = "Finding duplicates"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case failed = "Failed"
}

struct ScanProgress: Sendable {
    var phase: ScanPhase
    var totalFiles: Int
    var processedFiles: Int
    var currentFile: String?
    var bytesProcessed: Int64
    var totalBytes: Int64
    var startTime: Date?
    var error: String?

    nonisolated init(
        phase: ScanPhase = .idle,
        totalFiles: Int = 0,
        processedFiles: Int = 0,
        currentFile: String? = nil,
        bytesProcessed: Int64 = 0,
        totalBytes: Int64 = 0,
        startTime: Date? = nil,
        error: String? = nil
    ) {
        self.phase = phase
        self.totalFiles = totalFiles
        self.processedFiles = processedFiles
        self.currentFile = currentFile
        self.bytesProcessed = bytesProcessed
        self.totalBytes = totalBytes
        self.startTime = startTime
        self.error = error
    }

    var fileProgress: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles)
    }

    var byteProgress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesProcessed) / Double(totalBytes)
    }

    var elapsedTime: TimeInterval? {
        guard let start = startTime else { return nil }
        return Date().timeIntervalSince(start)
    }

    var isActive: Bool {
        switch phase {
        case .idle, .completed, .cancelled, .failed:
            return false
        default:
            return true
        }
    }

    static let idle = ScanProgress()
}
