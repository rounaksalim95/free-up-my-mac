import SwiftUI

/// Main idle view with folder selection and start scan button
struct MainView: View {
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        VStack(spacing: 0) {
            // SECTION 1: Header (fixed)
            VStack(spacing: 16) {
                // Compact title row
                HStack(spacing: 12) {
                    Image(systemName: viewModel.scanMode.iconName)
                        .font(.system(size: 36))
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Free Up My Mac")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(viewModel.scanMode.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 200, alignment: .leading)
                    }
                }

                // Mode selector
                ScanModeSelector(selectedMode: $viewModel.scanMode)

                // Size threshold (always reserve space to prevent layout shift)
                SizeThresholdInputView(minimumSize: $viewModel.minimumFileSize)
                    .frame(maxWidth: 500)
                    .opacity(viewModel.scanMode == .largeFiles ? 1 : 0)
                    .allowsHitTesting(viewModel.scanMode == .largeFiles)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // SECTION 2: Folder selection (flexible, takes remaining space)
            FolderSelectionView(viewModel: viewModel)
                .frame(maxWidth: 600)
                .padding(.horizontal, 32)

            Spacer(minLength: 16)

            // SECTION 3: Footer (fixed, always visible)
            VStack(spacing: 8) {
                Button {
                    Task {
                        await viewModel.startScan()
                    }
                } label: {
                    Label("Start Scan", systemImage: "magnifyingglass")
                        .font(.title3)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canStartScan)
                .keyboardShortcut(.return, modifiers: .command)

                if viewModel.selectedFolders.isEmpty {
                    Text("Select one or more folders to scan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.scanMode)
    }
}

#Preview("Duplicates Mode") {
    MainView(viewModel: ScanViewModel())
        .frame(width: 800, height: 700)
}

#Preview("Large Files Mode") {
    let viewModel = ScanViewModel()
    viewModel.scanMode = .largeFiles
    return MainView(viewModel: viewModel)
        .frame(width: 800, height: 700)
}

#Preview("With Folders Selected") {
    let viewModel = ScanViewModel()
    viewModel.addFolder(URL(fileURLWithPath: "/Users/test/Documents"))
    viewModel.addFolder(URL(fileURLWithPath: "/Users/test/Downloads"))
    return MainView(viewModel: viewModel)
        .frame(width: 800, height: 700)
}
