import Foundation
import xxHash_Swift

actor FileHasherService {
    private let partialHashSize: Int

    init(partialHashSize: Int = 4096) {
        self.partialHashSize = partialHashSize
    }

    func computePartialHash(for file: ScannedFile) async throws -> String {
        fatalError("Not yet implemented")
    }

    func computeFullHash(for file: ScannedFile) async throws -> String {
        fatalError("Not yet implemented")
    }

    func computePartialHashes(
        for files: [ScannedFile],
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> [ScannedFile] {
        fatalError("Not yet implemented")
    }

    func computeFullHashes(
        for files: [ScannedFile],
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> [ScannedFile] {
        fatalError("Not yet implemented")
    }
}
