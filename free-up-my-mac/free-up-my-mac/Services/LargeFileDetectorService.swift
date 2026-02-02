import Foundation
import os

/// Service for detecting and grouping large files by parent folder
actor LargeFileDetectorService {
    private static let logger = Logger(subsystem: "com.freeup.mac", category: "LargeFileDetectorService")
    private var isCancelled = false

    /// Result of large file detection
    struct DetectionResult: Sendable {
        let largeFileGroups: [LargeFileGroup]
        let totalFilesFound: Int
        let totalSize: Int64
    }

    /// Find large files and group them by parent folder
    /// - Parameters:
    ///   - files: The scanned files to filter
    ///   - minimumSize: Minimum file size in bytes to include
    ///   - progress: Progress callback
    /// - Returns: Detection result with grouped large files
    func findLargeFiles(
        in files: [ScannedFile],
        minimumSize: Int64,
        progress: @escaping @Sendable (ScanProgress) -> Void
    ) async throws -> DetectionResult {
        isCancelled = false
        let startTime = Date()

        // Report initial progress
        progress(ScanProgress(
            phase: .findingDuplicates,
            totalFiles: files.count,
            processedFiles: 0,
            startTime: startTime
        ))

        // Filter files by minimum size
        var largeFiles: [ScannedFile] = []
        var processedCount = 0

        for file in files {
            if isCancelled {
                throw ScanError.cancelled
            }

            if file.size >= minimumSize {
                largeFiles.append(file)
            }

            processedCount += 1

            // Report progress every 100 files
            if processedCount % 100 == 0 {
                progress(ScanProgress(
                    phase: .findingDuplicates,
                    totalFiles: files.count,
                    processedFiles: processedCount,
                    startTime: startTime
                ))
            }

            // Yield periodically for UI responsiveness
            if processedCount % 50 == 0 {
                await Task.yield()
            }
        }

        // Group files by parent folder
        var folderGroups: [URL: [ScannedFile]] = [:]

        for file in largeFiles {
            let folderURL = file.url.deletingLastPathComponent()
            folderGroups[folderURL, default: []].append(file)
        }

        // Convert to LargeFileGroup array and sort by total size descending
        var groups = folderGroups.map { (folderURL, files) in
            LargeFileGroup(folderURL: folderURL, files: files)
        }
        groups.sort { $0.totalSize > $1.totalSize }

        // Sort files within each group by size descending
        for i in groups.indices {
            groups[i].files.sort { $0.size > $1.size }
        }

        let totalSize = largeFiles.reduce(0) { $0 + $1.size }

        // Report completion
        progress(ScanProgress(
            phase: .completed,
            totalFiles: files.count,
            processedFiles: files.count,
            bytesProcessed: totalSize,
            totalBytes: totalSize,
            startTime: startTime
        ))

        Self.logger.info("Found \(largeFiles.count) large files in \(groups.count) folders, total size: \(totalSize)")

        return DetectionResult(
            largeFileGroups: groups,
            totalFilesFound: largeFiles.count,
            totalSize: totalSize
        )
    }

    /// Cancel an in-progress detection
    func cancel() {
        isCancelled = true
    }

    /// Calculate the date range (oldest and newest) from a set of files
    static func calculateDateRange(from files: [ScannedFile]) -> (oldest: Date, newest: Date)? {
        guard !files.isEmpty else { return nil }

        var oldest = Date.distantFuture
        var newest = Date.distantPast

        for file in files {
            if let date = file.modificationDate {
                if date < oldest { oldest = date }
                if date > newest { newest = date }
            }
        }

        // If no files have dates, return nil
        if oldest == Date.distantFuture || newest == Date.distantPast {
            return nil
        }

        return (oldest, newest)
    }
}
