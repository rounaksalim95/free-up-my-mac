import SwiftUI

/// Segmented control for switching between scan modes
struct ScanModeSelector: View {
    @Binding var selectedMode: ScanMode

    var body: some View {
        Picker("Scan Mode", selection: $selectedMode) {
            ForEach(ScanMode.allCases, id: \.self) { mode in
                Label(mode.displayName, systemImage: mode.iconName)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var mode: ScanMode = .duplicates

        var body: some View {
            VStack(spacing: 20) {
                ScanModeSelector(selectedMode: $mode)

                Text("Selected: \(mode.displayName)")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
