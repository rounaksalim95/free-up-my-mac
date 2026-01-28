import Foundation

actor DuplicateDetectorService {
    private let hasherService: FileHasherService
    private let smallFileThreshold: Int64
    private var isCancelled = false

    /// Result of duplicate detection including any files that failed during hashing
    struct DetectionResult: Sendable {
        let duplicateGroups: [DuplicateGroup]
        let skippedFiles: [SkippedFile]
    }

    init(hasherService: FileHasherService = FileHasherService(), smallFileThreshold: Int64 = 8192) {
        self.hasherService = hasherService
        self.smallFileThreshold = smallFileThreshold
    }

    // MARK: - Cancellation

    func cancel() async {
        isCancelled = true
        await hasherService.cancel()
    }

    private func resetCancellation() async {
        isCancelled = false
        await hasherService.resetCancellation()
    }

    // MARK: - Main Detection Algorithm

    func findDuplicates(
        in files: [ScannedFile],
        progress: @escaping @Sendable (ScanProgress) -> Void
    ) async throws -> DetectionResult {
        await resetCancellation()

        if files.isEmpty {
            progress(ScanProgress(phase: .completed))
            return DetectionResult(duplicateGroups: [], skippedFiles: [])
        }

        let startTime = Date()
        var allSkippedFiles: [SkippedFile] = []

        // Stage 1: Group by size
        progress(ScanProgress(
            phase: .groupingBySize,
            totalFiles: files.count,
            startTime: startTime
        ))

        if isCancelled { throw HashError.cancelled }

        let sizeGroups = groupBySize(files)

        if sizeGroups.isEmpty {
            progress(ScanProgress(phase: .completed, totalFiles: files.count, processedFiles: files.count, startTime: startTime))
            return DetectionResult(duplicateGroups: [], skippedFiles: [])
        }

        // Separate small file groups from large file groups (preserving group structure)
        var smallFileGroups: [[ScannedFile]] = []
        var largeFileGroups: [[ScannedFile]] = []

        for group in sizeGroups {
            // All files in a group have the same size, so check the first one
            if let firstFile = group.first, firstFile.size <= smallFileThreshold {
                smallFileGroups.append(group)
            } else {
                largeFileGroups.append(group)
            }
        }

        // Stage 2: Compute partial hashes for large files only
        var partialHashedLargeGroups: [[ScannedFile]] = []
        if !largeFileGroups.isEmpty {
            let largeFiles = largeFileGroups.flatMap { $0 }

            progress(ScanProgress(
                phase: .computingPartialHashes,
                totalFiles: largeFiles.count,
                processedFiles: 0,
                startTime: startTime
            ))

            if isCancelled { throw HashError.cancelled }

            let partialHashResult = try await hasherService.computePartialHashes(for: largeFiles) { processed, total in
                progress(ScanProgress(
                    phase: .computingPartialHashes,
                    totalFiles: total,
                    processedFiles: processed,
                    startTime: startTime
                ))
            }

            allSkippedFiles.append(contentsOf: partialHashResult.skippedFiles)

            // Rebuild groups from hashed files (some files may have been skipped due to errors)
            partialHashedLargeGroups = rebuildSizeGroups(from: partialHashResult.files)
        }

        // Filter large files using partial hash (no need to re-group by size, already grouped)
        let filteredLargeGroups = filterPotentialDuplicates(partialHashedLargeGroups)
        let filteredLargeFiles = filteredLargeGroups.flatMap { $0 }

        // Stage 3: Compute full hashes for filtered large files + all small files
        let smallFiles = smallFileGroups.flatMap { $0 }
        let filesToFullHash = filteredLargeFiles + smallFiles

        if isCancelled { throw HashError.cancelled }

        var fullHashedFiles: [ScannedFile] = []
        if !filesToFullHash.isEmpty {
            progress(ScanProgress(
                phase: .computingFullHashes,
                totalFiles: filesToFullHash.count,
                processedFiles: 0,
                startTime: startTime
            ))

            let fullHashResult = try await hasherService.computeFullHashes(for: filesToFullHash) { processed, total in
                progress(ScanProgress(
                    phase: .computingFullHashes,
                    totalFiles: total,
                    processedFiles: processed,
                    startTime: startTime
                ))
            }

            allSkippedFiles.append(contentsOf: fullHashResult.skippedFiles)
            fullHashedFiles = fullHashResult.files
        }

        // Stage 4: Build duplicate groups
        progress(ScanProgress(
            phase: .findingDuplicates,
            totalFiles: fullHashedFiles.count,
            processedFiles: 0,
            startTime: startTime
        ))

        if isCancelled { throw HashError.cancelled }

        let duplicateGroups = buildDuplicateGroups(from: fullHashedFiles)

        // Sort by potential savings descending
        let sortedGroups = duplicateGroups.sorted { $0.potentialSavings > $1.potentialSavings }

        progress(ScanProgress(
            phase: .completed,
            totalFiles: files.count,
            processedFiles: files.count,
            startTime: startTime
        ))

        return DetectionResult(duplicateGroups: sortedGroups, skippedFiles: allSkippedFiles)
    }

    // MARK: - Stage 1: Group by Size

    func groupBySize(_ files: [ScannedFile]) -> [[ScannedFile]] {
        var sizeDict: [Int64: [ScannedFile]] = [:]

        for file in files {
            sizeDict[file.size, default: []].append(file)
        }

        // Filter to keep only groups with 2+ files (potential duplicates)
        return sizeDict.values.filter { $0.count >= 2 }
    }

    // MARK: - Stage 2: Filter by Partial Hash

    func filterPotentialDuplicates(_ sizeGroups: [[ScannedFile]]) -> [[ScannedFile]] {
        var result: [[ScannedFile]] = []

        for group in sizeGroups {
            // Group by size + partial hash combination
            var hashDict: [String: [ScannedFile]] = [:]

            for file in group {
                let key = "\(file.size)-\(file.partialHash ?? "none")"
                hashDict[key, default: []].append(file)
            }

            // Keep only groups with 2+ files
            for (_, files) in hashDict where files.count >= 2 {
                result.append(files)
            }
        }

        return result
    }

    // MARK: - Private Helpers

    /// Rebuilds size groups from a flat array of files (used after hashing when some files may have been skipped)
    private func rebuildSizeGroups(from files: [ScannedFile]) -> [[ScannedFile]] {
        var sizeDict: [Int64: [ScannedFile]] = [:]

        for file in files {
            sizeDict[file.size, default: []].append(file)
        }

        // Filter to keep only groups with 2+ files
        return sizeDict.values.filter { $0.count >= 2 }
    }

    /// Build final duplicate groups from files with full hashes
    private func buildDuplicateGroups(from files: [ScannedFile]) -> [DuplicateGroup] {
        // Group by size + full hash
        var hashDict: [String: [ScannedFile]] = [:]

        for file in files {
            guard let fullHash = file.fullHash else { continue }
            let key = "\(file.size)-\(fullHash)"
            hashDict[key, default: []].append(file)
        }

        // Convert to DuplicateGroup, keeping only groups with 2+ files
        var groups: [DuplicateGroup] = []

        for (_, groupFiles) in hashDict where groupFiles.count >= 2 {
            guard let first = groupFiles.first, let hash = first.fullHash else { continue }

            let group = DuplicateGroup(
                hash: hash,
                size: first.size,
                files: groupFiles
            )
            groups.append(group)
        }

        return groups
    }
}
