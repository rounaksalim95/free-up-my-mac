import Foundation

/// Provides mock duplicate data from scanned files for UI testing
/// until the actual DuplicateDetectorService is implemented
enum MockDataProvider {

    /// Generate mock duplicate groups from scanned files by grouping files with the same size
    /// - Parameter files: The scanned files to process
    /// - Returns: Array of DuplicateGroup where files with same size are grouped together
    static func generateMockDuplicates(from files: [ScannedFile]) -> [DuplicateGroup] {
        // Group files by size
        var sizeGroups: [Int64: [ScannedFile]] = [:]

        for file in files {
            sizeGroups[file.size, default: []].append(file)
        }

        // Create duplicate groups from files with same size (simulating duplicates)
        var duplicateGroups: [DuplicateGroup] = []

        for (size, groupFiles) in sizeGroups {
            // Only consider groups with 2+ files as duplicates
            if groupFiles.count >= 2 {
                let group = DuplicateGroup(
                    hash: "mock-\(size)-\(UUID().uuidString.prefix(8))",
                    size: size,
                    files: groupFiles
                )
                duplicateGroups.append(group)
            }
        }

        // Sort by potential savings (largest first)
        return duplicateGroups.sorted { $0.potentialSavings > $1.potentialSavings }
    }

    /// Generate synthetic duplicate groups for SwiftUI previews
    /// - Parameter count: Number of groups to generate
    /// - Returns: Array of mock DuplicateGroup instances
    static func generatePreviewDuplicates(count: Int = 5) -> [DuplicateGroup] {
        let fileTypes = ["jpg", "png", "pdf", "doc", "mp3", "mov", "zip"]
        let sizes: [Int64] = [1024 * 50, 1024 * 200, 1024 * 512, 1024 * 1024, 1024 * 1024 * 5]

        var groups: [DuplicateGroup] = []

        for i in 0..<count {
            let fileType = fileTypes[i % fileTypes.count]
            let size = sizes[i % sizes.count]
            let fileCount = Int.random(in: 2...5)

            var files: [ScannedFile] = []
            for j in 0..<fileCount {
                let fileName = "file_\(i)_copy\(j).\(fileType)"
                let paths = ["/Users/user/Documents", "/Users/user/Downloads", "/Users/user/Desktop", "/Users/user/Pictures"]
                let path = paths[j % paths.count]

                let file = ScannedFile(
                    url: URL(fileURLWithPath: "\(path)/\(fileName)"),
                    size: size,
                    creationDate: Date().addingTimeInterval(TimeInterval(-86400 * j)),
                    modificationDate: Date().addingTimeInterval(TimeInterval(-3600 * j))
                )
                files.append(file)
            }

            let group = DuplicateGroup(
                hash: "preview-\(UUID().uuidString.prefix(8))",
                size: size,
                files: files
            )
            groups.append(group)
        }

        return groups.sorted { $0.potentialSavings > $1.potentialSavings }
    }

    /// Generate mock history sessions for preview
    static func generatePreviewSessions(count: Int = 3) -> [CleanupSession] {
        var sessions: [CleanupSession] = []

        for i in 0..<count {
            let session = CleanupSession(
                date: Date().addingTimeInterval(TimeInterval(-86400 * i)),
                scannedDirectory: "/Users/user/\(["Documents", "Downloads", "Desktop"][i % 3])",
                filesDeleted: Int.random(in: 5...50),
                bytesRecovered: Int64.random(in: 1024 * 1024...1024 * 1024 * 500),
                duplicateGroupsCleaned: Int.random(in: 2...15)
            )
            sessions.append(session)
        }

        return sessions
    }

    /// Generate mock savings stats for preview
    static func generatePreviewStats() -> SavingsStats {
        SavingsStats(
            totalFilesDeleted: 127,
            totalBytesRecovered: 2_500_000_000, // ~2.5 GB
            totalSessionsCompleted: 8
        )
    }
}
