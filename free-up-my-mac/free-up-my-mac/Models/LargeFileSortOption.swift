import Foundation

/// Sort options for large files
enum LargeFileSortOption: String, Sendable, CaseIterable, Identifiable {
    case sizeDesc = "size_desc"
    case sizeAsc = "size_asc"
    case dateDesc = "date_desc"
    case dateAsc = "date_asc"
    case combinedScoreDesc = "combined_desc"
    case combinedScoreAsc = "combined_asc"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sizeDesc:
            return "Largest First"
        case .sizeAsc:
            return "Smallest First"
        case .dateDesc:
            return "Newest First"
        case .dateAsc:
            return "Oldest First"
        case .combinedScoreDesc:
            return "Best Cleanup First"
        case .combinedScoreAsc:
            return "Best Cleanup Last"
        }
    }

    var iconName: String {
        switch self {
        case .sizeDesc, .sizeAsc:
            return "square.stack.3d.up"
        case .dateDesc, .dateAsc:
            return "calendar"
        case .combinedScoreDesc, .combinedScoreAsc:
            return "chart.bar.fill"
        }
    }

    /// Short label for compact display
    var shortLabel: String {
        switch self {
        case .sizeDesc:
            return "Size ↓"
        case .sizeAsc:
            return "Size ↑"
        case .dateDesc:
            return "Date ↓"
        case .dateAsc:
            return "Date ↑"
        case .combinedScoreDesc:
            return "Score ↓"
        case .combinedScoreAsc:
            return "Score ↑"
        }
    }
}
