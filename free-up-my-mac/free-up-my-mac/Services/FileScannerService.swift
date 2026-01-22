import Foundation

/// Errors that can occur during file scanning
enum ScanError: Error, Sendable, Equatable {
    case cancelled
    case directoryNotFound(URL)
    case accessDenied(URL)
}

actor FileScannerService {
    private let filters: FileFilters
    private var isCancelled = false

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

    /// Scan a directory and return all files matching the filter criteria
    /// - Parameters:
    ///   - url: The directory URL to scan
    ///   - progress: A callback for progress updates
    /// - Returns: Array of scanned files
    func scanDirectory(
        at url: URL,
        progress: @escaping @Sendable (ScanProgress) -> Void
    ) async throws -> [ScannedFile] {
        // Reset cancellation flag
        isCancelled = false

        // Verify directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ScanError.directoryNotFound(url)
        }

        var scannedFiles: [ScannedFile] = []
        var processedCount = 0
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

                // Report progress periodically
                if processedCount % progressBatchSize == 0 {
                    progress(ScanProgress(
                        phase: .enumerating,
                        totalFiles: processedCount,
                        processedFiles: processedCount,
                        currentFile: fileURL.path,
                        bytesProcessed: scannedFiles.reduce(0) { $0 + $1.size },
                        startTime: startTime
                    ))
                }

            } catch {
                // Handle permission errors gracefully - skip the file and continue
                // Log the error but don't stop scanning
                continue
            }
        }

        // Report final progress
        let totalBytes = scannedFiles.reduce(0) { $0 + $1.size }
        progress(ScanProgress(
            phase: .completed,
            totalFiles: scannedFiles.count,
            processedFiles: scannedFiles.count,
            bytesProcessed: totalBytes,
            totalBytes: totalBytes,
            startTime: startTime
        ))

        return scannedFiles
    }

    /// Cancel an in-progress scan
    func cancelScan() {
        isCancelled = true
    }
}
