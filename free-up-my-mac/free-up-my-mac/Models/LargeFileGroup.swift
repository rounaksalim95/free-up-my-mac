import Foundation

/// Represents a group of large files in the same parent folder
struct LargeFileGroup: Identifiable, Hashable, Sendable {
    let id: UUID
    let folderURL: URL
    var files: [ScannedFile]

    init(
        id: UUID = UUID(),
        folderURL: URL,
        files: [ScannedFile]
    ) {
        self.id = id
        self.folderURL = folderURL
        self.files = files
    }

    var folderName: String {
        folderURL.lastPathComponent
    }

    var folderPath: String {
        folderURL.path
    }

    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    var fileCount: Int {
        files.count
    }

    /// Returns files sorted by the given sort option
    func filesSorted(by sortOption: LargeFileSortOption, dateRange: (oldest: Date, newest: Date)? = nil) -> [ScannedFile] {
        switch sortOption {
        case .sizeDesc:
            return files.sorted { $0.size > $1.size }
        case .sizeAsc:
            return files.sorted { $0.size < $1.size }
        case .dateDesc:
            return files.sorted { ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast) }
        case .dateAsc:
            return files.sorted { ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast) }
        case .combinedScoreDesc:
            guard let range = dateRange else {
                return files.sorted { $0.size > $1.size }
            }
            let maxSize = files.map(\.size).max() ?? 1
            return files.sorted {
                combinedScore(file: $0, maxSize: maxSize, dateRange: range) >
                combinedScore(file: $1, maxSize: maxSize, dateRange: range)
            }
        case .combinedScoreAsc:
            guard let range = dateRange else {
                return files.sorted { $0.size < $1.size }
            }
            let maxSize = files.map(\.size).max() ?? 1
            return files.sorted {
                combinedScore(file: $0, maxSize: maxSize, dateRange: range) <
                combinedScore(file: $1, maxSize: maxSize, dateRange: range)
            }
        }
    }

    /// Calculate combined score: 60% size, 40% age (larger + older = higher score)
    private func combinedScore(file: ScannedFile, maxSize: Int64, dateRange: (oldest: Date, newest: Date)) -> Double {
        let sizeScore = Double(file.size) / Double(max(maxSize, 1))
        let fileDate = file.modificationDate ?? dateRange.newest
        let age = dateRange.newest.timeIntervalSince(fileDate)
        let totalRange = dateRange.newest.timeIntervalSince(dateRange.oldest)
        let ageScore = totalRange > 0 ? age / totalRange : 0
        return (sizeScore * 0.6) + (ageScore * 0.4)
    }
}
