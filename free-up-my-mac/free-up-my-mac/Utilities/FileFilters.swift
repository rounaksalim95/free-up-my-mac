import Foundation

struct FileFilters: Sendable {
    var minimumFileSize: Int64
    var excludeHiddenFiles: Bool
    var excludeSystemDirectories: Bool
    var excludedExtensions: Set<String>
    var excludedDirectoryNames: Set<String>

    nonisolated init(
        minimumFileSize: Int64 = 1024,
        excludeHiddenFiles: Bool = true,
        excludeSystemDirectories: Bool = true,
        excludedExtensions: Set<String> = [],
        excludedDirectoryNames: Set<String> = []
    ) {
        self.minimumFileSize = minimumFileSize
        self.excludeHiddenFiles = excludeHiddenFiles
        self.excludeSystemDirectories = excludeSystemDirectories
        self.excludedExtensions = excludedExtensions
        self.excludedDirectoryNames = excludedDirectoryNames
    }

    nonisolated static let `default` = FileFilters()

    nonisolated static let systemDirectories: Set<String> = [
        ".Trash",
        ".Spotlight-V100",
        ".fseventsd",
        ".DocumentRevisions-V100",
        ".TemporaryItems",
        ".git",
        ".svn",
        "node_modules",
        ".DS_Store"
    ]

    nonisolated static let systemPaths: Set<String> = [
        "/Library",
        "/System",
        "/Applications"
    ]

    nonisolated func shouldIncludeFile(at url: URL, size: Int64) -> Bool {
        if size < minimumFileSize {
            return false
        }

        let fileName = url.lastPathComponent

        if excludeHiddenFiles && fileName.hasPrefix(".") {
            return false
        }

        let ext = url.pathExtension.lowercased()
        if excludedExtensions.contains(ext) {
            return false
        }

        return true
    }

    nonisolated func shouldTraverseDirectory(at url: URL) -> Bool {
        let dirName = url.lastPathComponent

        if excludeHiddenFiles && dirName.hasPrefix(".") {
            return false
        }

        if excludeSystemDirectories {
            if Self.systemDirectories.contains(dirName) {
                return false
            }

            let path = url.path
            for systemPath in Self.systemPaths {
                if path == systemPath || path.hasPrefix(systemPath + "/") {
                    return false
                }
            }
        }

        if excludedDirectoryNames.contains(dirName) {
            return false
        }

        return true
    }
}
