import SwiftUI

/// Sort and filter controls for results view
struct SortFilterBar: View {
    @Binding var sortOption: SortOption
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
                    ForEach(SortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
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
                .frame(width: 120)
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

/// Sort options for duplicate groups
enum SortOption: String, CaseIterable, Identifiable {
    case savingsDesc = "savings_desc"
    case savingsAsc = "savings_asc"
    case sizeDesc = "size_desc"
    case sizeAsc = "size_asc"
    case countDesc = "count_desc"
    case countAsc = "count_asc"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .savingsDesc: return "Savings (High to Low)"
        case .savingsAsc: return "Savings (Low to High)"
        case .sizeDesc: return "Size (Largest First)"
        case .sizeAsc: return "Size (Smallest First)"
        case .countDesc: return "Count (Most Files)"
        case .countAsc: return "Count (Fewest Files)"
        }
    }
}

#Preview {
    SortFilterBar(
        sortOption: .constant(.savingsDesc),
        filterExtension: .constant(nil),
        availableExtensions: ["jpg", "png", "pdf", "doc"],
        onSelectAll: {},
        onDeselectAll: {},
        selectedCount: 5,
        totalCount: 23
    )
    .frame(width: 800)
}
