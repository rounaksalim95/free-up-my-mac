import Foundation

enum FileOperationError: Error, Sendable {
    case fileNotFound(URL)
    case permissionDenied(URL)
    case deletionFailed(URL, Error)
    case trashFailed(URL, Error)
}

actor FileOperationService {

    func moveToTrash(_ files: [ScannedFile]) async throws -> Int64 {
        fatalError("Not yet implemented")
    }

    func deleteFile(at url: URL) async throws {
        fatalError("Not yet implemented")
    }

    func moveToTrash(at url: URL) async throws {
        fatalError("Not yet implemented")
    }

    func deleteDuplicates(
        in group: DuplicateGroup,
        keeping original: ScannedFile
    ) async throws -> Int64 {
        fatalError("Not yet implemented")
    }

    func revealInFinder(_ file: ScannedFile) {
        fatalError("Not yet implemented")
    }

    func openFile(_ file: ScannedFile) {
        fatalError("Not yet implemented")
    }
}
