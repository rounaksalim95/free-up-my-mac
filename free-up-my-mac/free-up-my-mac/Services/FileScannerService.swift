import Foundation

actor FileScannerService {
    private let filters: FileFilters

    init(filters: FileFilters = .default) {
        self.filters = filters
    }

    func scanDirectory(
        at url: URL,
        progress: @escaping @Sendable (ScanProgress) -> Void
    ) async throws -> [ScannedFile] {
        fatalError("Not yet implemented")
    }

    func cancelScan() {
        fatalError("Not yet implemented")
    }
}
