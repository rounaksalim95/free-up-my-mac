import Foundation
import AppKit

enum FileOperationError: Error, Sendable {
    case fileNotFound(URL)
    case permissionDenied(URL)
    case deletionFailed(URL, Error)
    case trashFailed(URL, Error)
    case partialFailure(trashedCount: Int, bytesFreed: Int64, errors: [FileOperationError])
}

actor FileOperationService {

    /// Move a batch of files to trash, returning total bytes freed
    /// Throws partialFailure if some files fail but others succeed
    func moveToTrash(_ files: [ScannedFile]) async throws -> Int64 {
        guard !files.isEmpty else { return 0 }

        var bytesFreed: Int64 = 0
        var trashedCount = 0
        var errors: [FileOperationError] = []

        for file in files {
            do {
                try await moveToTrash(at: file.url)
                bytesFreed += file.size
                trashedCount += 1
            } catch let error as FileOperationError {
                errors.append(error)
            } catch {
                errors.append(.trashFailed(file.url, error))
            }
        }

        // If some files failed but others succeeded, throw partialFailure
        if !errors.isEmpty {
            throw FileOperationError.partialFailure(
                trashedCount: trashedCount,
                bytesFreed: bytesFreed,
                errors: errors
            )
        }

        return bytesFreed
    }

    /// Permanently delete a file (not recommended - use moveToTrash instead)
    func deleteFile(at url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileOperationError.fileNotFound(url)
        }

        guard FileManager.default.isWritableFile(atPath: url.path) else {
            throw FileOperationError.permissionDenied(url)
        }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw FileOperationError.deletionFailed(url, error)
        }
    }

    /// Move a single file to trash
    func moveToTrash(at url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileOperationError.fileNotFound(url)
        }

        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        } catch let error as NSError {
            // Check for specific error codes
            if error.domain == NSCocoaErrorDomain {
                switch error.code {
                case NSFileNoSuchFileError:
                    throw FileOperationError.fileNotFound(url)
                case NSFileWriteNoPermissionError:
                    throw FileOperationError.permissionDenied(url)
                default:
                    throw FileOperationError.trashFailed(url, error)
                }
            }
            throw FileOperationError.trashFailed(url, error)
        }
    }

    /// Delete all duplicates in a group except the original file
    func deleteDuplicates(
        in group: DuplicateGroup,
        keeping original: ScannedFile
    ) async throws -> Int64 {
        let filesToTrash = group.files.filter { $0.id != original.id }
        return try await moveToTrash(filesToTrash)
    }

    /// Reveal file in Finder
    nonisolated func revealInFinder(_ file: ScannedFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    /// Open file with default application
    nonisolated func openFile(_ file: ScannedFile) {
        NSWorkspace.shared.open(file.url)
    }
}
