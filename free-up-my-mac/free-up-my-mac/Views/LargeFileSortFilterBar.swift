import SwiftUI

/// Sort and filter controls for large files results view
struct LargeFileSortFilterBar: View {
    @Binding var sortOption: LargeFileSortOption
    @Binding var filterExtension: String?
    let availableExtensions: [String]
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let selectedCount: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 16) {
            // Sort picker
            HStack(spacing: 8) {
                Text("Sort by:")
                    .foregroundStyle(.secondary)

                Picker("Sort", selection: $sortOption) {
                    Section("Size") {
                        Text(LargeFileSortOption.sizeDesc.displayName)
                            .tag(LargeFileSortOption.sizeDesc)
                        Text(LargeFileSortOption.sizeAsc.displayName)
                            .tag(LargeFileSortOption.sizeAsc)
                    }
                    Section("Date Modified") {
                        Text(LargeFileSortOption.dateDesc.displayName)
                            .tag(LargeFileSortOption.dateDesc)
                        Text(LargeFileSortOption.dateAsc.displayName)
                            .tag(LargeFileSortOption.dateAsc)
                    }
                    Section("Combined Score") {
                        Text(LargeFileSortOption.combinedScoreDesc.displayName)
                            .tag(LargeFileSortOption.combinedScoreDesc)
                        Text(LargeFileSortOption.combinedScoreAsc.displayName)
                            .tag(LargeFileSortOption.combinedScoreAsc)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 160, maxWidth: 250)
            }

            Divider()
                .frame(height: 20)

            // Filter by extension
            HStack(spacing: 8) {
                Text("Filter:")
                    .foregroundStyle(.secondary)

                Picker("Extension", selection: Binding(
                    get: { filterExtension ?? "all" },
                    set: { filterExtension = $0 == "all" ? nil : $0 }
                )) {
                    Text("All types").tag("all")
                    Divider()
                    ForEach(availableExtensions, id: \.self) { ext in
                        Text(".\(ext)").tag(ext)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 120, maxWidth: 200)
            }

            Spacer()

            // Selection controls
            HStack(spacing: 12) {
                Text("\(selectedCount) of \(totalCount) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Button("Select All") {
                    onSelectAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Deselect All") {
                    onDeselectAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selectedCount == 0)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    LargeFileSortFilterBar(
        sortOption: .constant(.sizeDesc),
        filterExtension: .constant(nil),
        availableExtensions: ["jpg", "png", "pdf", "mov", "mp4"],
        onSelectAll: {},
        onDeselectAll: {},
        selectedCount: 3,
        totalCount: 15
    )
    .frame(width: 800)
}
