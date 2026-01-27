import SwiftUI

/// A shareable card view displaying cleanup achievements
/// Designed for rendering to an image at 600x400 pixels
struct ShareCardView: View {
    let stats: SavingsStats
    let latestSavings: Int64?

    /// Fixed dimensions for image rendering
    static let width: CGFloat = 600
    static let height: CGFloat = 400

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.top, 32)

            Spacer()

            // Main callout
            mainCallout
                .padding(.horizontal, 32)

            Spacer()

            // Stats row
            statsRow
                .padding(.horizontal, 32)

            Spacer()

            // Footer
            footer
                .padding(.bottom, 24)
        }
        .frame(width: Self.width, height: Self.height)
        .background(backgroundGradient)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // App icon placeholder (system icon)
            Image(systemName: "trash.slash.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white)

            Text("Free Up My Mac")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Main Callout

    private var mainCallout: some View {
        VStack(spacing: 8) {
            if let savings = latestSavings, savings > 0 {
                Text("I just freed up")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.9))

                Text(ByteFormatter.format(savings))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("Total Space Recovered")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.9))

                Text(ByteFormatter.format(stats.totalBytesRecovered))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 40) {
            statItem(
                value: ByteFormatter.format(stats.totalBytesRecovered),
                label: "Total Saved"
            )

            statItem(
                value: "\(stats.totalFilesDeleted)",
                label: "Files Cleaned"
            )

            statItem(
                value: "\(stats.totalSessionsCompleted)",
                label: "Cleanups"
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Download free: freeupmymac.app")
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.7))
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.2, green: 0.6, blue: 0.4),  // Green
                Color(red: 0.1, green: 0.4, blue: 0.5)   // Teal
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Previews

#Preview("With Latest Savings") {
    ShareCardView(
        stats: SavingsStats(
            totalFilesDeleted: 127,
            totalBytesRecovered: 2_500_000_000,
            totalSessionsCompleted: 8
        ),
        latestSavings: 500_000_000
    )
}

#Preview("Without Latest Savings") {
    ShareCardView(
        stats: SavingsStats(
            totalFilesDeleted: 127,
            totalBytesRecovered: 2_500_000_000,
            totalSessionsCompleted: 8
        ),
        latestSavings: nil
    )
}

#Preview("Empty Stats") {
    ShareCardView(
        stats: .empty,
        latestSavings: nil
    )
}
