import Foundation

/// Represents the type of scan operation to perform
enum ScanMode: String, Sendable, CaseIterable {
    case duplicates
    case largeFiles

    var displayName: String {
        switch self {
        case .duplicates:
            return "Duplicates"
        case .largeFiles:
            return "Large Files"
        }
    }

    var description: String {
        switch self {
        case .duplicates:
            return "Find and remove duplicate files"
        case .largeFiles:
            return "Find large files taking up space"
        }
    }

    var iconName: String {
        switch self {
        case .duplicates:
            return "doc.on.doc.fill"
        case .largeFiles:
            return "externaldrive.fill"
        }
    }
}
