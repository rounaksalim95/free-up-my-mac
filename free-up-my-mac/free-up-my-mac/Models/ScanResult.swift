import Foundation

struct ScanResult: Sendable {
    let scanDate: Date
    let scannedDirectory: URL
    let totalFilesScanned: Int
    let totalBytesScanned: Int64
    let duplicateGroups: [DuplicateGroup]
    let scanDuration: TimeInterval
    let errors: [String]
    let skippedFiles: [SkippedFile]

    init(
        scanDate: Date = Date(),
        scannedDirectory: URL,
        totalFilesScanned: Int,
        totalBytesScanned: Int64,
        duplicateGroups: [DuplicateGroup],
        scanDuration: TimeInterval,
        errors: [String] = [],
        skippedFiles: [SkippedFile] = []
    ) {
        self.scanDate = scanDate
        self.scannedDirectory = scannedDirectory
        self.totalFilesScanned = totalFilesScanned
        self.totalBytesScanned = totalBytesScanned
        self.duplicateGroups = duplicateGroups
        self.scanDuration = scanDuration
        self.errors = errors
        self.skippedFiles = skippedFiles
    }

    var totalDuplicateFiles: Int {
        duplicateGroups.reduce(0) { $0 + $1.duplicateCount }
    }

    var totalDuplicateGroups: Int {
        duplicateGroups.count
    }

    var potentialSavings: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.potentialSavings }
    }
}
