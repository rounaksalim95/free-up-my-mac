import SwiftUI

/// NSViewRepresentable to capture a view for share sheet anchoring
struct ShareAnchorView: NSViewRepresentable {
    @Binding var nsView: NSView?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.nsView = view
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.nsView = nsView
        }
    }
}

/// History sheet showing past cleanup sessions and cumulative stats
struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()
    @State private var showClearConfirmation = false
    @State private var sessionToDelete: CleanupSession?
    @State private var shareAnchorView: NSView?
    @Environment(\.dismiss) private var dismiss

    private let shareService = ShareService()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cleanup History")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if !viewModel.sessions.isEmpty {
                    // Share button
                    Button {
                        presentShareSheet()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .background(
                        ShareAnchorView(nsView: $shareAnchorView)
                            .frame(width: 1, height: 1)
                    )

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

            if viewModel.isLoading {
                ProgressView("Loading history...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sessions.isEmpty {
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
                                    sessionToDelete = session
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await viewModel.loadData()
        }
        .alert("Clear History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                Task {
                    await viewModel.clearHistory()
                }
            }
        } message: {
            Text("This will permanently delete all cleanup history. This action cannot be undone.")
        }
        .alert("Delete Session", isPresented: .init(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    Task {
                        await viewModel.deleteSession(session)
                    }
                }
                sessionToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this cleanup session from history?")
        }
    }

    // MARK: - Share Sheet

    private func presentShareSheet() {
        guard let stats = viewModel.stats,
              let anchorView = shareAnchorView else {
            return
        }

        // Get latest session's savings if available
        let latestSavings = viewModel.sessions.first?.bytesRecovered

        // Generate share content
        let text = shareService.generateShareText(stats: stats, latestSavings: latestSavings)
        let image = shareService.generateShareImage(stats: stats, latestSavings: latestSavings)

        // Present share sheet
        shareService.presentShareSheet(text: text, image: image, from: anchorView)
    }

    // MARK: - Empty State

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
        }
    }
    return EmptyHistoryPreview()
}
