import Foundation

/// Service for fetching disk usage information
actor DiskSpaceService {

    /// Represents disk usage information
    struct DiskUsage: Sendable, Equatable {
        let totalBytes: Int64
        let usedBytes: Int64

        var freeBytes: Int64 {
            totalBytes - usedBytes
        }

        var usedPercentage: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(usedBytes) / Double(totalBytes)
        }

        var freePercentage: Double {
            1.0 - usedPercentage
        }

        /// Returns the color category for the usage level
        var usageLevel: UsageLevel {
            let percentage = usedPercentage
            if percentage < 0.7 {
                return .normal
            } else if percentage < 0.9 {
                return .warning
            } else {
                return .critical
            }
        }
    }

    /// Usage level categories for color coding
    enum UsageLevel: Sendable {
        case normal    // < 70% - green
        case warning   // 70-90% - yellow
        case critical  // > 90% - red
    }

    /// Error types for disk space operations
    enum DiskSpaceError: Error, Sendable {
        case unableToRetrieveVolumeInfo
        case invalidVolumeInfo
    }

    /// Get the current disk usage for the boot volume
    func getDiskUsage() throws -> DiskUsage {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let values = try homeURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ])

        guard let totalCapacity = values.volumeTotalCapacity,
              let availableCapacity = values.volumeAvailableCapacity else {
            throw DiskSpaceError.invalidVolumeInfo
        }

        let total = Int64(totalCapacity)
        let available = Int64(availableCapacity)
        let used = total - available

        return DiskUsage(totalBytes: total, usedBytes: used)
    }

    /// Get disk usage with more accurate available space (for APFS volumes)
    /// This uses volumeAvailableCapacityForImportantUsage which accounts for purgeable space
    func getDiskUsageImportant() throws -> DiskUsage {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let values = try homeURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])

        guard let totalCapacity = values.volumeTotalCapacity,
              let availableCapacity = values.volumeAvailableCapacityForImportantUsage else {
            throw DiskSpaceError.invalidVolumeInfo
        }

        let total = Int64(totalCapacity)
        let available = availableCapacity
        let used = total - available

        return DiskUsage(totalBytes: total, usedBytes: used)
    }
}
