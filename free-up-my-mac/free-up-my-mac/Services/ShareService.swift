import Foundation
import AppKit
import SwiftUI

/// Service for sharing cleanup achievements and generating reports
struct ShareService: Sendable {

    // MARK: - Text Generation

    /// Generate shareable text summarizing cleanup stats
    func generateShareText(stats: SavingsStats, latestSavings: Int64?) -> String {
        var lines: [String] = []

        if let savings = latestSavings, savings > 0 {
            lines.append("I just freed up \(ByteFormatter.format(savings)) on my Mac!")
        } else {
            lines.append("I've been cleaning up my Mac!")
        }

        lines.append("")
        lines.append("Total space recovered: \(ByteFormatter.format(stats.totalBytesRecovered))")
        lines.append("Files deleted: \(stats.totalFilesDeleted)")
        lines.append("Cleanup sessions: \(stats.totalSessionsCompleted)")
        lines.append("")
        lines.append("Try it free: freeupmymac.app")

        return lines.joined(separator: "\n")
    }

    // MARK: - Image Generation

    /// Generate a shareable image card
    @MainActor
    func generateShareImage(stats: SavingsStats, latestSavings: Int64?) -> NSImage? {
        let view = ShareCardView(stats: stats, latestSavings: latestSavings)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0 // Retina scale

        guard let cgImage = renderer.cgImage else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(
            width: ShareCardView.width,
            height: ShareCardView.height
        ))
    }

    // MARK: - Share Sheet

    /// Present native share sheet with text and optional image
    @MainActor
    func presentShareSheet(text: String, image: NSImage?, from view: NSView) {
        var items: [Any] = [text]

        if let img = image {
            items.append(img)
        }

        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    // MARK: - Clipboard

    /// Copy text to clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Report Generation

    /// Generate a text report from scan results
    func generateReport(from result: ScanResult) -> String {
        var lines: [String] = []

        lines.append("=== Free Up My Mac - Scan Report ===")
        lines.append("")
        lines.append("Scan Date: \(formatDate(result.scanDate))")
        lines.append("Scanned Directory: \(result.scannedDirectory.path)")
        lines.append("")
        lines.append("--- Summary ---")
        lines.append("Total Files Scanned: \(result.totalFilesScanned)")
        lines.append("Total Size Scanned: \(ByteFormatter.format(result.totalBytesScanned))")
        lines.append("Scan Duration: \(String(format: "%.1f", result.scanDuration)) seconds")
        lines.append("")
        lines.append("--- Duplicates Found ---")
        lines.append("Duplicate Groups: \(result.totalDuplicateGroups)")
        lines.append("Duplicate Files: \(result.totalDuplicateFiles)")
        lines.append("Potential Space Savings: \(ByteFormatter.format(result.potentialSavings))")

        if !result.duplicateGroups.isEmpty {
            lines.append("")
            lines.append("--- Duplicate Details ---")

            for (index, group) in result.duplicateGroups.enumerated() {
                lines.append("")
                lines.append("Group \(index + 1): \(group.files.count) files, \(ByteFormatter.format(group.size)) each")

                for file in group.files {
                    lines.append("  - \(file.url.path)")
                }
            }
        }

        if !result.errors.isEmpty {
            lines.append("")
            lines.append("--- Errors ---")
            for error in result.errors {
                lines.append("  - \(error)")
            }
        }

        lines.append("")
        lines.append("=== End of Report ===")

        return lines.joined(separator: "\n")
    }

    // MARK: - CSV Export

    /// Export duplicate groups to CSV format
    func exportToCSV(groups: [DuplicateGroup]) -> String {
        var lines: [String] = []

        // Header
        lines.append("Group,Hash,File Path,Size (bytes),Size (formatted),Created,Modified")

        // Data rows
        for (groupIndex, group) in groups.enumerated() {
            for file in group.files {
                let row = [
                    String(groupIndex + 1),
                    escapeCSV(group.hash),
                    escapeCSV(file.url.path),
                    String(file.size),
                    escapeCSV(ByteFormatter.format(file.size)),
                    escapeCSV(file.creationDate.map { formatDate($0) } ?? ""),
                    escapeCSV(file.modificationDate.map { formatDate($0) } ?? "")
                ]
                lines.append(row.joined(separator: ","))
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func escapeCSV(_ string: String) -> String {
        // If string contains comma, quote, or newline, wrap in quotes and escape existing quotes
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return string
    }
}
