import SwiftUI

/// Input view for selecting minimum file size threshold
struct SizeThresholdInputView: View {
    @Binding var minimumSize: Int64

    /// Preset size options in bytes
    private let presets: [(label: String, bytes: Int64)] = [
        ("100 MB", 100 * 1024 * 1024),
        ("500 MB", 500 * 1024 * 1024),
        ("1 GB", 1024 * 1024 * 1024),
        ("5 GB", 5 * 1024 * 1024 * 1024)
    ]

    @State private var customSizeText: String = ""
    @State private var customSizeUnit: SizeUnit = .MB
    @State private var showCustomInput: Bool = false

    enum SizeUnit: String, CaseIterable {
        case MB = "MB"
        case GB = "GB"

        var multiplier: Int64 {
            switch self {
            case .MB: return 1024 * 1024
            case .GB: return 1024 * 1024 * 1024
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Minimum file size")
                .font(.headline)

            HStack(spacing: 8) {
                // Preset buttons
                ForEach(presets, id: \.bytes) { preset in
                    Button {
                        minimumSize = preset.bytes
                        showCustomInput = false
                    } label: {
                        Text(preset.label)
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(minimumSize == preset.bytes && !showCustomInput ? .accentColor : .secondary)
                }

                // Custom button
                Button {
                    showCustomInput.toggle()
                    if showCustomInput {
                        // Initialize custom input from current size
                        updateCustomInputFromMinimumSize()
                    }
                } label: {
                    Text("Custom")
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(showCustomInput ? .accentColor : .secondary)
            }

            // Custom size input
            if showCustomInput {
                HStack(spacing: 8) {
                    TextField("Size", text: $customSizeText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: customSizeText) { _, newValue in
                            updateMinimumSizeFromCustomInput()
                        }

                    Picker("Unit", selection: $customSizeUnit) {
                        ForEach(SizeUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                    .onChange(of: customSizeUnit) { _, _ in
                        updateMinimumSizeFromCustomInput()
                    }

                    Text("= \(ByteFormatter.format(minimumSize))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Files smaller than this will be ignored")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func updateCustomInputFromMinimumSize() {
        // Try to express in GB first if it's a whole number
        let gbValue = minimumSize / (1024 * 1024 * 1024)
        if gbValue > 0 && minimumSize == gbValue * 1024 * 1024 * 1024 {
            customSizeText = "\(gbValue)"
            customSizeUnit = .GB
        } else {
            // Express in MB
            let mbValue = minimumSize / (1024 * 1024)
            customSizeText = "\(mbValue)"
            customSizeUnit = .MB
        }
    }

    private func updateMinimumSizeFromCustomInput() {
        guard let value = Int64(customSizeText), value > 0 else {
            return
        }
        minimumSize = value * customSizeUnit.multiplier
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var size: Int64 = 100 * 1024 * 1024

        var body: some View {
            VStack(spacing: 20) {
                SizeThresholdInputView(minimumSize: $size)

                Divider()

                Text("Current: \(ByteFormatter.format(size))")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(width: 500)
        }
    }

    return PreviewWrapper()
}
