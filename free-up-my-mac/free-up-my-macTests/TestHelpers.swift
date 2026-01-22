import Foundation

/// A helper struct for creating temporary test directories with files
struct TestDirectory {
    let url: URL

    /// Create a new temporary test directory
    static func create() throws -> TestDirectory {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("free-up-my-mac-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        return TestDirectory(url: testDir)
    }

    /// Add a file with specified name and size
    @discardableResult
    func addFile(name: String, size: Int, content: Data? = nil) throws -> URL {
        let fileURL = url.appendingPathComponent(name)
        let data: Data
        if let providedContent = content {
            data = providedContent
        } else {
            data = Data(repeating: 0x41, count: size) // Fill with 'A' characters
        }
        try data.write(to: fileURL)
        return fileURL
    }

    /// Add a subdirectory with specified name
    @discardableResult
    func addSubdirectory(name: String) throws -> URL {
        let subDir = url.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        return subDir
    }

    /// Add a file to a subdirectory
    @discardableResult
    func addFile(name: String, size: Int, in subdirectory: URL, content: Data? = nil) throws -> URL {
        let fileURL = subdirectory.appendingPathComponent(name)
        let data: Data
        if let providedContent = content {
            data = providedContent
        } else {
            data = Data(repeating: 0x41, count: size)
        }
        try data.write(to: fileURL)
        return fileURL
    }

    /// Clean up the test directory
    func cleanup() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

/// Extension to create a test directory structure matching the plan
extension TestDirectory {
    /// Creates a standard test structure:
    /// TestScanDirectory/
    /// ├── file1.txt (1 KB)
    /// ├── file2.pdf (2 KB)
    /// ├── .hidden_file (1 KB)
    /// ├── small_file.txt (100 bytes - below threshold)
    /// ├── SubFolder/
    /// │   └── nested_file.txt (1 KB)
    /// └── .git/
    ///     └── config
    static func createStandardTestStructure() throws -> TestDirectory {
        let testDir = try create()

        // Regular files
        try testDir.addFile(name: "file1.txt", size: 1024)
        try testDir.addFile(name: "file2.pdf", size: 2048)

        // Hidden file
        try testDir.addFile(name: ".hidden_file", size: 1024)

        // Small file (below threshold)
        try testDir.addFile(name: "small_file.txt", size: 100)

        // Subdirectory with nested file
        let subFolder = try testDir.addSubdirectory(name: "SubFolder")
        try testDir.addFile(name: "nested_file.txt", size: 1024, in: subFolder)

        // Hidden .git directory (should be skipped)
        let gitDir = try testDir.addSubdirectory(name: ".git")
        try testDir.addFile(name: "config", size: 512, in: gitDir)

        return testDir
    }
}
