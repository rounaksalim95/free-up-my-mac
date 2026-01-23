import Foundation
import xxHash_Swift

enum HashError: Error, Sendable, Equatable {
    case fileNotFound(URL)
    case readError(URL, String)
    case cancelled
}

actor FileHasherService {
    private let partialHashSize: Int
    private let chunkSize: Int
    private let maxConcurrentOperations: Int
    private let smallFileThreshold: Int64
    private var isCancelled = false

    init(
        partialHashSize: Int = 4096,
        chunkSize: Int = 65536,
        maxConcurrentOperations: Int = 4,
        smallFileThreshold: Int64 = 8192
    ) {
        self.partialHashSize = partialHashSize
        self.chunkSize = chunkSize
        self.maxConcurrentOperations = maxConcurrentOperations
        self.smallFileThreshold = smallFileThreshold
    }

    // MARK: - Cancellation

    func cancel() {
        isCancelled = true
    }

    func resetCancellation() {
        isCancelled = false
    }

    func checkCancelled() throws {
        if isCancelled { throw HashError.cancelled }
    }

    // MARK: - Single File Hashing

    func computePartialHash(for file: ScannedFile) async throws -> String {
        try checkCancelled()

        // For small files, delegate to full hash
        if file.size <= smallFileThreshold {
            return try await computeFullHash(for: file)
        }

        // Perform I/O work outside actor isolation for true parallelism
        return try Self.computePartialHashSync(
            for: file,
            partialHashSize: partialHashSize
        )
    }

    func computeFullHash(for file: ScannedFile) async throws -> String {
        try checkCancelled()

        // Perform I/O work outside actor isolation for true parallelism
        return try Self.computeFullHashSync(
            for: file,
            chunkSize: chunkSize
        )
    }

    // MARK: - Batch Hashing

    func computePartialHashes(
        for files: [ScannedFile],
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> [ScannedFile] {
        if files.isEmpty { return [] }

        let partialSize = partialHashSize
        let threshold = smallFileThreshold
        let chunk = chunkSize

        return try await processBatch(files: files, progress: progress) { file in
            var updatedFile = file
            if file.size <= threshold {
                updatedFile.partialHash = try Self.computeFullHashSync(for: file, chunkSize: chunk)
            } else {
                updatedFile.partialHash = try Self.computePartialHashSync(for: file, partialHashSize: partialSize)
            }
            return updatedFile
        }
    }

    func computeFullHashes(
        for files: [ScannedFile],
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> [ScannedFile] {
        if files.isEmpty { return [] }

        let chunk = chunkSize

        return try await processBatch(files: files, progress: progress) { file in
            var updatedFile = file
            updatedFile.fullHash = try Self.computeFullHashSync(for: file, chunkSize: chunk)
            return updatedFile
        }
    }

    // MARK: - Private Helpers

    private func processBatch(
        files: [ScannedFile],
        progress: @escaping @Sendable (Int, Int) -> Void,
        transform: @escaping @Sendable (ScannedFile) throws -> ScannedFile
    ) async throws -> [ScannedFile] {
        let total = files.count
        var processedCount = 0
        var results: [ScannedFile] = []
        results.reserveCapacity(total)

        // Process in chunks to limit concurrency
        let chunks = stride(from: 0, to: files.count, by: maxConcurrentOperations).map {
            Array(files[$0..<min($0 + maxConcurrentOperations, files.count)])
        }

        for chunk in chunks {
            try checkCancelled()

            // Process chunk concurrently using throwing task group
            let chunkResults = try await withThrowingTaskGroup(of: ScannedFile?.self) { group in
                for file in chunk {
                    group.addTask {
                        do {
                            return try transform(file)
                        } catch let error as HashError where error != .cancelled {
                            // Skip files that fail due to permission/read errors
                            return nil
                        }
                        // HashError.cancelled and other errors propagate up
                    }
                }

                var chunkFiles: [ScannedFile] = []
                for try await result in group {
                    if let file = result {
                        chunkFiles.append(file)
                    }
                }
                return chunkFiles
            }

            results.append(contentsOf: chunkResults)
            processedCount += chunk.count

            // Report progress
            progress(processedCount, total)

            // Yield for UI responsiveness (every 50 files)
            if processedCount % 50 == 0 {
                await Task.yield()
            }
        }

        return results
    }

    // MARK: - Nonisolated Static Helpers (for true parallel execution)

    /// Computes partial hash synchronously - can run in parallel across multiple tasks
    private nonisolated static func computePartialHashSync(
        for file: ScannedFile,
        partialHashSize: Int
    ) throws -> String {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: file.url.path) else {
            throw HashError.fileNotFound(file.url)
        }

        guard let handle = try? FileHandle(forReadingFrom: file.url) else {
            throw HashError.readError(file.url, "Unable to open file for reading")
        }

        defer { try? handle.close() }

        do {
            // Read first partialHashSize bytes
            let firstData = try handle.read(upToCount: partialHashSize) ?? Data()

            // Seek to last partialHashSize bytes
            let lastOffset = max(0, UInt64(file.size) - UInt64(partialHashSize))
            try handle.seek(toOffset: lastOffset)
            let lastData = try handle.read(upToCount: partialHashSize) ?? Data()

            // Combine and hash
            var combinedData = firstData
            combinedData.append(lastData)

            let hash = XXH64.digest(combinedData)
            return String(format: "%016llx", hash)

        } catch let error as HashError {
            throw error
        } catch {
            throw HashError.readError(file.url, error.localizedDescription)
        }
    }

    /// Computes full hash synchronously - can run in parallel across multiple tasks
    private nonisolated static func computeFullHashSync(
        for file: ScannedFile,
        chunkSize: Int
    ) throws -> String {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: file.url.path) else {
            throw HashError.fileNotFound(file.url)
        }

        guard let handle = try? FileHandle(forReadingFrom: file.url) else {
            throw HashError.readError(file.url, "Unable to open file for reading")
        }

        defer { try? handle.close() }

        do {
            var hasher = XXH64()

            while true {
                let chunk = try handle.read(upToCount: chunkSize)
                guard let data = chunk, !data.isEmpty else { break }
                hasher.update(data)
            }

            let hash = hasher.digest()
            return String(format: "%016llx", hash)

        } catch let error as HashError {
            throw error
        } catch {
            throw HashError.readError(file.url, error.localizedDescription)
        }
    }
}
