import SwiftUI

/// Card showing cumulative savings stats
struct TotalSavingsCard: View {
    let stats: SavingsStats

    var body: some View {
        VStack(spacing: 16) {
            // Main savings display
            VStack(spacing: 4) {
                Text("Total Space Recovered")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(ByteFormatter.format(stats.totalBytesRecovered))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.green)
            }

            Divider()

            // Additional stats
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(stats.totalFilesDeleted)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()

                    Text("Files Deleted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(stats.totalSessionsCompleted)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()

                    Text("Cleanups")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    TotalSavingsCard(stats: SavingsStats(
        totalFilesDeleted: 127,
        totalBytesRecovered: 2_500_000_000,
        totalSessionsCompleted: 8
    ))
    .frame(width: 400)
    .padding()
}

#Preview("Empty") {
    TotalSavingsCard(stats: .empty)
        .frame(width: 400)
        .padding()
}
