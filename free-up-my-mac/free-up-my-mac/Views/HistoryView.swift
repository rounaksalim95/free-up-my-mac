import SwiftUI

/// History sheet showing past cleanup sessions and cumulative stats
struct HistoryView: View {
    @State private var viewModel = HistoryViewModel.preview
    @State private var showClearConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cleanup History")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if !viewModel.sessions.isEmpty {
                    Button("Clear All") {
                        showClearConfirmation = true
                    }
                    .foregroundStyle(.red)
                }

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Total savings card
                        if let stats = viewModel.stats {
                            TotalSavingsCard(stats: stats)
                        }

                        // Sessions list
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Sessions")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(viewModel.sessions) { session in
                                SessionRowView(session: session) {
                                    viewModel.deleteSession(session)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .alert("Clear History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("This will permanently delete all cleanup history. This action cannot be undone.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No History Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your cleanup sessions will appear here after you remove duplicate files.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HistoryView()
}

#Preview("Empty History") {
    struct EmptyHistoryPreview: View {
        var body: some View {
            HistoryView()
                .onAppear {
                    // This won't actually work in preview, but shows intent
                }
        }
    }
    return EmptyHistoryPreview()
}
