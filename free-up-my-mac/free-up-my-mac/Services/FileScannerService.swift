import Foundation
import os

/// Errors that can occur during file scanning
enum ScanError: Error, Sendable, Equatable {
    case cancelled
    case directoryNotFound(URL)
    case accessDenied(URL)
}

actor FileScannerService {
    private let filters: FileFilters
    private var isCancelled = false
    private static let logger = Logger(subsystem: "com.freeup.mac", category: "FileScannerService")

    /// Resource keys to pre-fetch for efficient file enumeration
    private static let resourceKeys: [URLResourceKey] = [
        .fileSizeKey,
        .creationDateKey,
        .contentModificationDateKey,
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey
    ]

    init(filters: FileFilters = .default) {
        self.filters = filters
    }

    /// Scan result containing files and any skipped files
    struct ScanDirectoryResult: Sendable {
        let files: [ScannedFile]
        let skippedFiles: [SkippedFile]
    }

    /// Scan a directory and return all files matching the filter criteria
    /// - Parameters:
    ///   - url: The directory URL to scan
    ///   - progress: A callback for progress updates
    /// - Returns: Array of scanned files
    func scanDirectory(
        at url: URL,
        progress: @escaping @Sendable (ScanProgress) -> Void
    ) async throws -> [ScannedFile] {
        let result = try await scanDirectoryWithSkipped(at: url, progress: progress)
        return result.files
    }

    /// Scan a directory and return all files matching the filter criteria, including skipped files
    /// - Parameters:
    ///   - url: The directory URL to scan
    ///   - progress: A callback for progress updates
    /// - Returns: ScanDirectoryResult containing files and skipped files
    func scanDirectoryWithSkipped(
        at url: URL,
        progress: @escaping @Sendable (ScanProgress) -> Void
    ) async throws -> ScanDirectoryResult {
        // Reset cancellation flag
        isCancelled = false

        // Verify directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ScanError.directoryNotFound(url)
        }

        var scannedFiles: [ScannedFile] = []
        var skippedFiles: [SkippedFile] = []
        var processedCount = 0
        var totalBytesProcessed: Int64 = 0
        let startTime = Date()

        // Report initial progress
        progress(ScanProgress(
            phase: .enumerating,
            totalFiles: 0,
            processedFiles: 0,
            currentFile: url.path,
            startTime: startTime
        ))

        // Create enumerator with options to not descend into packages
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Self.resourceKeys,
            options: [.skipsPackageDescendants]
        ) else {
            throw ScanError.accessDenied(url)
        }

        // Batch size for progress updates
        let progressBatchSize = 100
        var batchCount = 0

        for case let fileURL as URL in enumerator {
            // Check for cancellation
            if isCancelled {
                throw ScanError.cancelled
            }

            // Yield periodically to keep UI responsive
            if batchCount % 50 == 0 {
                await Task.yield()
            }
            batchCount += 1

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(Self.resourceKeys))

                // Skip symbolic links
                if resourceValues.isSymbolicLink == true {
                    continue
                }

                // Handle directories
                if resourceValues.isDirectory == true {
                    // Check if we should traverse this directory
                    if !filters.shouldTraverseDirectory(at: fileURL) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                // Only process regular files
                guard resourceValues.isRegularFile == true else {
                    continue
                }

                // Get file size
                let fileSize = Int64(resourceValues.fileSize ?? 0)

                // Apply file filters
                guard filters.shouldIncludeFile(at: fileURL, size: fileSize) else {
                    continue
                }

                // Create ScannedFile
                let scannedFile = ScannedFile(
                    url: fileURL,
                    size: fileSize,
                    creationDate: resourceValues.creationDate,
                    modificationDate: resourceValues.contentModificationDate
                )

                scannedFiles.append(scannedFile)
                processedCount += 1
                totalBytesProcessed += fileSize

                // Report progress periodically
                if processedCount % progressBatchSize == 0 {
                    progress(ScanProgress(
                        phase: .enumerating,
                        totalFiles: processedCount,
                        processedFiles: processedCount,
                        currentFile: fileURL.path,
                        bytesProcessed: totalBytesProcessed,
                        startTime: startTime,
                        skippedFilesCount: skippedFiles.count
                    ))
                }

            } catch {
                // Handle permission errors gracefully - skip the file and continue
                Self.logger.error("Skipped file \(fileURL.path): \(error.localizedDescription)")
                skippedFiles.append(SkippedFile(url: fileURL, reason: .permissionDenied))
                continue
            }
        }

        // Report final progress
        progress(ScanProgress(
            phase: .completed,
            totalFiles: scannedFiles.count,
            processedFiles: scannedFiles.count,
            bytesProcessed: totalBytesProcessed,
            totalBytes: totalBytesProcessed,
            startTime: startTime,
            skippedFilesCount: skippedFiles.count
        ))

        return ScanDirectoryResult(files: scannedFiles, skippedFiles: skippedFiles)
    }

    /// Cancel an in-progress scan
    func cancelScan() {
        isCancelled = true
    }
}
