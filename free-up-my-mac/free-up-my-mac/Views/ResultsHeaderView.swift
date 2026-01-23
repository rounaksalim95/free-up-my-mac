import SwiftUI

/// Summary statistics header for results view
struct ResultsHeaderView: View {
    let totalGroups: Int
    let totalFiles: Int
    let potentialSavings: Int64
    let scannedFolders: [URL]

    var body: some View {
        HStack(spacing: 24) {
            // Duplicate groups stat
            StatCard(
                title: "Duplicate Groups",
                value: "\(totalGroups)",
                icon: "square.on.square"
            )

            // Total files stat
            StatCard(
                title: "Duplicate Files",
                value: "\(totalFiles)",
                icon: "doc.on.doc"
            )

            // Potential savings
            StatCard(
                title: "Potential Savings",
                value: ByteFormatter.formatCompact(potentialSavings),
                icon: "arrow.down.circle",
                valueColor: .green
            )

            Spacer()

            // Scanned folders summary
            VStack(alignment: .trailing, spacing: 4) {
                Text("Scanned \(scannedFolders.count) folder\(scannedFolders.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let first = scannedFolders.first {
                    Text(first.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// Individual stat card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(valueColor)
                    .monospacedDigit()

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ResultsHeaderView(
        totalGroups: 15,
        totalFiles: 47,
        potentialSavings: 1024 * 1024 * 256,
        scannedFolders: [
            URL(fileURLWithPath: "/Users/test/Documents"),
            URL(fileURLWithPath: "/Users/test/Downloads")
        ]
    )
    .frame(width: 800)
}
