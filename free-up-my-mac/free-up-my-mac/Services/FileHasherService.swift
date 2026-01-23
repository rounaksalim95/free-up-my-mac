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

    // MARK: - Single File Hashing

    func computePartialHash(for file: ScannedFile) async throws -> String {
        if isCancelled { throw HashError.cancelled }

        // For small files, delegate to full hash
        if file.size <= smallFileThreshold {
            return try await computeFullHash(for: file)
        }

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

    func computeFullHash(for file: ScannedFile) async throws -> String {
        if isCancelled { throw HashError.cancelled }

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
                if isCancelled { throw HashError.cancelled }

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

    // MARK: - Batch Hashing

    func computePartialHashes(
        for files: [ScannedFile],
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> [ScannedFile] {
        if files.isEmpty { return [] }

        return try await processBatch(files: files, progress: progress) { file in
            var updatedFile = file
            updatedFile.partialHash = try await self.computePartialHash(for: file)
            return updatedFile
        }
    }

    func computeFullHashes(
        for files: [ScannedFile],
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> [ScannedFile] {
        if files.isEmpty { return [] }

        return try await processBatch(files: files, progress: progress) { file in
            var updatedFile = file
            updatedFile.fullHash = try await self.computeFullHash(for: file)
            return updatedFile
        }
    }

    // MARK: - Private Helpers

    private func processBatch(
        files: [ScannedFile],
        progress: @escaping @Sendable (Int, Int) -> Void,
        transform: @escaping (ScannedFile) async throws -> ScannedFile
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
            if isCancelled { throw HashError.cancelled }

            // Process chunk concurrently
            let chunkResults = await withTaskGroup(of: ScannedFile?.self) { group in
                for file in chunk {
                    group.addTask {
                        do {
                            return try await transform(file)
                        } catch {
                            // Skip files that fail (permission errors, etc.)
                            return nil
                        }
                    }
                }

                var chunkFiles: [ScannedFile] = []
                for await result in group {
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
}
