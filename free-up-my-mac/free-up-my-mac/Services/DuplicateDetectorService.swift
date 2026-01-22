import Foundation

actor DuplicateDetectorService {

    func findDuplicates(
        in files: [ScannedFile],
        progress: @escaping @Sendable (ScanProgress) -> Void
    ) async throws -> [DuplicateGroup] {
        fatalError("Not yet implemented")
    }

    func groupBySize(_ files: [ScannedFile]) -> [[ScannedFile]] {
        fatalError("Not yet implemented")
    }

    func filterPotentialDuplicates(_ sizeGroups: [[ScannedFile]]) -> [[ScannedFile]] {
        fatalError("Not yet implemented")
    }
}
