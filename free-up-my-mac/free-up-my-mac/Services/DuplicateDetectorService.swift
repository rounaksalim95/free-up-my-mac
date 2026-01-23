import Foundation

actor DuplicateDetectorService {
    private let hasherService: FileHasherService
    private let smallFileThreshold: Int64
    private var isCancelled = false

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
    ) async throws -> [DuplicateGroup] {
        await resetCancellation()

        if files.isEmpty {
            progress(ScanProgress(phase: .completed))
            return []
        }

        let startTime = Date()

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
            return []
        }

        // Separate small files from large files
        var smallFiles: [ScannedFile] = []
        var largeFiles: [ScannedFile] = []

        for group in sizeGroups {
            for file in group {
                if file.size < smallFileThreshold {
                    smallFiles.append(file)
                } else {
                    largeFiles.append(file)
                }
            }
        }

        // Stage 2: Compute partial hashes for large files only
        var partialHashedLargeFiles: [ScannedFile] = []
        if !largeFiles.isEmpty {
            progress(ScanProgress(
                phase: .computingPartialHashes,
                totalFiles: largeFiles.count,
                processedFiles: 0,
                startTime: startTime
            ))

            if isCancelled { throw HashError.cancelled }

            partialHashedLargeFiles = try await hasherService.computePartialHashes(for: largeFiles) { processed, total in
                progress(ScanProgress(
                    phase: .computingPartialHashes,
                    totalFiles: total,
                    processedFiles: processed,
                    startTime: startTime
                ))
            }
        }

        // Filter large files using partial hash
        let largeFileGroups = groupBySize(partialHashedLargeFiles)
        let filteredLargeGroups = filterPotentialDuplicates(largeFileGroups)
        let filteredLargeFiles = filteredLargeGroups.flatMap { $0 }

        // Stage 3: Compute full hashes for filtered large files + all small files
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

            fullHashedFiles = try await hasherService.computeFullHashes(for: filesToFullHash) { processed, total in
                progress(ScanProgress(
                    phase: .computingFullHashes,
                    totalFiles: total,
                    processedFiles: processed,
                    startTime: startTime
                ))
            }
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

        return sortedGroups
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

    // MARK: - Stage 4: Build Duplicate Groups

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
