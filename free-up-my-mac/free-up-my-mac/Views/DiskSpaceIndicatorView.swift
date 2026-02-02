import SwiftUI

/// Displays disk space usage with a progress bar and color coding
struct DiskSpaceIndicatorView: View {
    let diskUsage: DiskSpaceService.DiskUsage?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "internaldrive")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            if let usage = diskUsage {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(ByteFormatter.format(usage.usedBytes)) used of \(ByteFormatter.format(usage.totalBytes))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(ByteFormatter.format(usage.freeBytes)) free")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: .separatorColor))
                                .frame(height: 8)

                            // Used space fill
                            RoundedRectangle(cornerRadius: 4)
                                .fill(usageColor(for: usage.usageLevel))
                                .frame(width: geometry.size.width * usage.usedPercentage, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            } else {
                Text("Loading disk space...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func usageColor(for level: DiskSpaceService.UsageLevel) -> Color {
        switch level {
        case .normal:
            return .green
        case .warning:
            return .yellow
        case .critical:
            return .red
        }
    }
}

#Preview("Normal Usage") {
    let usage = DiskSpaceService.DiskUsage(
        totalBytes: 500 * 1024 * 1024 * 1024,
        usedBytes: 245 * 1024 * 1024 * 1024
    )
    return DiskSpaceIndicatorView(diskUsage: usage)
        .frame(width: 400)
}

#Preview("Warning Usage") {
    let usage = DiskSpaceService.DiskUsage(
        totalBytes: 500 * 1024 * 1024 * 1024,
        usedBytes: 400 * 1024 * 1024 * 1024
    )
    return DiskSpaceIndicatorView(diskUsage: usage)
        .frame(width: 400)
}

#Preview("Critical Usage") {
    let usage = DiskSpaceService.DiskUsage(
        totalBytes: 500 * 1024 * 1024 * 1024,
        usedBytes: 470 * 1024 * 1024 * 1024
    )
    return DiskSpaceIndicatorView(diskUsage: usage)
        .frame(width: 400)
}

#Preview("Loading") {
    DiskSpaceIndicatorView(diskUsage: nil)
        .frame(width: 400)
}
