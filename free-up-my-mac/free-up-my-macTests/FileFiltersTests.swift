import Testing
import Foundation
@testable import free_up_my_mac

@Suite("FileFilters Tests")
struct FileFiltersTests {

    // MARK: - shouldIncludeFile Tests

    @Test("Excludes files below minimum size")
    func testShouldIncludeFile_ExcludesBelowMinimumSize() {
        let filters = FileFilters(minimumFileSize: 1024)
        let url = URL(fileURLWithPath: "/test/file.txt")

        #expect(filters.shouldIncludeFile(at: url, size: 500) == false)
        #expect(filters.shouldIncludeFile(at: url, size: 1023) == false)
    }

    @Test("Includes files at minimum size")
    func testShouldIncludeFile_IncludesAtMinimumSize() {
        let filters = FileFilters(minimumFileSize: 1024)
        let url = URL(fileURLWithPath: "/test/file.txt")

        #expect(filters.shouldIncludeFile(at: url, size: 1024) == true)
        #expect(filters.shouldIncludeFile(at: url, size: 2048) == true)
    }

    @Test("Excludes hidden files when enabled")
    func testShouldIncludeFile_ExcludesHiddenFilesWhenEnabled() {
        let filters = FileFilters(excludeHiddenFiles: true)
        let hiddenURL = URL(fileURLWithPath: "/test/.hidden_file")
        let visibleURL = URL(fileURLWithPath: "/test/visible_file")

        #expect(filters.shouldIncludeFile(at: hiddenURL, size: 2048) == false)
        #expect(filters.shouldIncludeFile(at: visibleURL, size: 2048) == true)
    }

    @Test("Includes hidden files when disabled")
    func testShouldIncludeFile_IncludesHiddenFilesWhenDisabled() {
        let filters = FileFilters(excludeHiddenFiles: false)
        let hiddenURL = URL(fileURLWithPath: "/test/.hidden_file")

        #expect(filters.shouldIncludeFile(at: hiddenURL, size: 2048) == true)
    }

    @Test("Excludes files with excluded extensions")
    func testShouldIncludeFile_ExcludesExtensions() {
        let filters = FileFilters(excludedExtensions: ["tmp", "log", "cache"])
        let tmpURL = URL(fileURLWithPath: "/test/file.tmp")
        let logURL = URL(fileURLWithPath: "/test/file.log")
        let txtURL = URL(fileURLWithPath: "/test/file.txt")

        #expect(filters.shouldIncludeFile(at: tmpURL, size: 2048) == false)
        #expect(filters.shouldIncludeFile(at: logURL, size: 2048) == false)
        #expect(filters.shouldIncludeFile(at: txtURL, size: 2048) == true)
    }

    @Test("Extension check is case insensitive")
    func testShouldIncludeFile_ExtensionCaseInsensitive() {
        let filters = FileFilters(excludedExtensions: ["tmp"])
        let upperURL = URL(fileURLWithPath: "/test/file.TMP")
        let mixedURL = URL(fileURLWithPath: "/test/file.Tmp")

        #expect(filters.shouldIncludeFile(at: upperURL, size: 2048) == false)
        #expect(filters.shouldIncludeFile(at: mixedURL, size: 2048) == false)
    }

    @Test("Default filters work correctly")
    func testShouldIncludeFile_DefaultFilters() {
        let filters = FileFilters.default

        let regularFile = URL(fileURLWithPath: "/test/document.pdf")
        let hiddenFile = URL(fileURLWithPath: "/test/.config")
        let smallFile = URL(fileURLWithPath: "/test/tiny.txt")

        #expect(filters.shouldIncludeFile(at: regularFile, size: 2048) == true)
        #expect(filters.shouldIncludeFile(at: hiddenFile, size: 2048) == false)
        #expect(filters.shouldIncludeFile(at: smallFile, size: 100) == false)
    }

    // MARK: - shouldTraverseDirectory Tests

    @Test("Excludes hidden directories when enabled")
    func testShouldTraverseDirectory_ExcludesHiddenDirectories() {
        let filters = FileFilters(excludeHiddenFiles: true)
        let hiddenDir = URL(fileURLWithPath: "/test/.hidden_dir")
        let visibleDir = URL(fileURLWithPath: "/test/visible_dir")

        #expect(filters.shouldTraverseDirectory(at: hiddenDir) == false)
        #expect(filters.shouldTraverseDirectory(at: visibleDir) == true)
    }

    @Test("Includes hidden directories when disabled")
    func testShouldTraverseDirectory_IncludesHiddenDirectoriesWhenDisabled() {
        let filters = FileFilters(excludeHiddenFiles: false, excludeSystemDirectories: false)
        let hiddenDir = URL(fileURLWithPath: "/test/.hidden_dir")

        #expect(filters.shouldTraverseDirectory(at: hiddenDir) == true)
    }

    @Test("Excludes .git directory")
    func testShouldTraverseDirectory_ExcludesGit() {
        let filters = FileFilters(excludeSystemDirectories: true)
        let gitDir = URL(fileURLWithPath: "/project/.git")

        #expect(filters.shouldTraverseDirectory(at: gitDir) == false)
    }

    @Test("Excludes node_modules directory")
    func testShouldTraverseDirectory_ExcludesNodeModules() {
        let filters = FileFilters(excludeSystemDirectories: true)
        let nodeModulesDir = URL(fileURLWithPath: "/project/node_modules")

        #expect(filters.shouldTraverseDirectory(at: nodeModulesDir) == false)
    }

    @Test("Excludes .Trash directory")
    func testShouldTraverseDirectory_ExcludesTrash() {
        let filters = FileFilters(excludeSystemDirectories: true)
        let trashDir = URL(fileURLWithPath: "/Users/test/.Trash")

        #expect(filters.shouldTraverseDirectory(at: trashDir) == false)
    }

    @Test("Excludes /Library path")
    func testShouldTraverseDirectory_ExcludesLibrary() {
        let filters = FileFilters(excludeSystemDirectories: true)
        let libraryDir = URL(fileURLWithPath: "/Library")
        let librarySubDir = URL(fileURLWithPath: "/Library/Preferences")

        #expect(filters.shouldTraverseDirectory(at: libraryDir) == false)
        #expect(filters.shouldTraverseDirectory(at: librarySubDir) == false)
    }

    @Test("Excludes /System path")
    func testShouldTraverseDirectory_ExcludesSystem() {
        let filters = FileFilters(excludeSystemDirectories: true)
        let systemDir = URL(fileURLWithPath: "/System")
        let systemSubDir = URL(fileURLWithPath: "/System/Library")

        #expect(filters.shouldTraverseDirectory(at: systemDir) == false)
        #expect(filters.shouldTraverseDirectory(at: systemSubDir) == false)
    }

    @Test("Excludes /Applications path")
    func testShouldTraverseDirectory_ExcludesApplications() {
        let filters = FileFilters(excludeSystemDirectories: true)
        let appsDir = URL(fileURLWithPath: "/Applications")
        let appsSubDir = URL(fileURLWithPath: "/Applications/Xcode.app")

        #expect(filters.shouldTraverseDirectory(at: appsDir) == false)
        #expect(filters.shouldTraverseDirectory(at: appsSubDir) == false)
    }

    @Test("Allows user ~/Library directory")
    func testShouldTraverseDirectory_AllowsUserLibrary() {
        let filters = FileFilters(excludeSystemDirectories: true)
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let userLibraryDir = homeDir.appendingPathComponent("Library")

        // User's ~/Library should NOT be blocked since it's not /Library
        #expect(filters.shouldTraverseDirectory(at: userLibraryDir) == true)
    }

    @Test("Excludes custom directory names")
    func testShouldTraverseDirectory_ExcludesCustomDirectoryNames() {
        let filters = FileFilters(excludedDirectoryNames: ["build", "dist", "__pycache__"])
        let buildDir = URL(fileURLWithPath: "/project/build")
        let distDir = URL(fileURLWithPath: "/project/dist")
        let pycacheDir = URL(fileURLWithPath: "/project/__pycache__")
        let srcDir = URL(fileURLWithPath: "/project/src")

        #expect(filters.shouldTraverseDirectory(at: buildDir) == false)
        #expect(filters.shouldTraverseDirectory(at: distDir) == false)
        #expect(filters.shouldTraverseDirectory(at: pycacheDir) == false)
        #expect(filters.shouldTraverseDirectory(at: srcDir) == true)
    }

    @Test("Allows regular directories")
    func testShouldTraverseDirectory_AllowsRegularDirectories() {
        let filters = FileFilters.default
        let documentsDir = URL(fileURLWithPath: "/Users/test/Documents")
        let downloadsDir = URL(fileURLWithPath: "/Users/test/Downloads")
        let projectDir = URL(fileURLWithPath: "/Users/test/Projects/my-app")

        #expect(filters.shouldTraverseDirectory(at: documentsDir) == true)
        #expect(filters.shouldTraverseDirectory(at: downloadsDir) == true)
        #expect(filters.shouldTraverseDirectory(at: projectDir) == true)
    }

    // MARK: - System Directories Static Property Tests

    @Test("System directories set contains expected entries")
    func testSystemDirectories_ContainsExpectedEntries() {
        let systemDirs = FileFilters.systemDirectories

        #expect(systemDirs.contains(".Trash"))
        #expect(systemDirs.contains(".git"))
        #expect(systemDirs.contains("node_modules"))
        #expect(systemDirs.contains(".DS_Store"))
        #expect(systemDirs.contains(".fseventsd"))
    }

    @Test("System paths set contains expected entries")
    func testSystemPaths_ContainsExpectedEntries() {
        let systemPaths = FileFilters.systemPaths

        #expect(systemPaths.contains("/Library"))
        #expect(systemPaths.contains("/System"))
        #expect(systemPaths.contains("/Applications"))
    }
}
