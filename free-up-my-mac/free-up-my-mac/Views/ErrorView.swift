import SwiftUI

/// Error display view with retry option
struct ErrorView: View {
    let message: String
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            // Error message
            VStack(spacing: 8) {
                Text("Scan Failed")
                    .font(.title)
                    .fontWeight(.bold)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Actions
            HStack(spacing: 16) {
                Button("Go Back") {
                    viewModel.resetToIdle()
                }
                .buttonStyle(.bordered)

                if viewModel.canStartScan {
                    Button("Try Again") {
                        Task {
                            await viewModel.startScan()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer()
        }
        .padding(32)
    }
}

#Preview {
    let viewModel = ScanViewModel()
    viewModel.addFolder(URL(fileURLWithPath: "/Users/test/Documents"))

    return ErrorView(
        message: "Could not access the selected folder. Please check permissions and try again.",
        viewModel: viewModel
    )
    .frame(width: 800, height: 600)
}
