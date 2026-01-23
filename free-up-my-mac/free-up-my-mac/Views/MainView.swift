import SwiftUI

/// Main idle view with folder selection and start scan button
struct MainView: View {
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App title and icon
            VStack(spacing: 16) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Free Up My Mac")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Find and remove duplicate files to reclaim disk space")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Folder selection area
            FolderSelectionView(viewModel: viewModel)
                .frame(maxWidth: 600)

            Spacer()

            // Start scan button
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

            Spacer()
        }
        .padding(32)
    }
}

#Preview {
    MainView(viewModel: ScanViewModel())
        .frame(width: 800, height: 600)
}

#Preview("With Folders Selected") {
    let viewModel = ScanViewModel()
    viewModel.addFolder(URL(fileURLWithPath: "/Users/test/Documents"))
    viewModel.addFolder(URL(fileURLWithPath: "/Users/test/Downloads"))
    return MainView(viewModel: viewModel)
        .frame(width: 800, height: 600)
}
