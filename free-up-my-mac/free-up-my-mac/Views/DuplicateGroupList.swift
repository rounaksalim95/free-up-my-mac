import SwiftUI

/// Scrollable list of duplicate groups
struct DuplicateGroupList: View {
    let groups: [DuplicateGroup]
    let selectedFileIds: Set<UUID>
    let onToggleFile: (UUID) -> Void
    let onRevealFile: (ScannedFile) -> Void
    let onQuickLook: (ScannedFile) -> Void

    var body: some View {
        if groups.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(groups) { group in
                        DuplicateGroupView(
                            group: group,
                            selectedFileIds: selectedFileIds,
                            onToggleFile: onToggleFile,
                            onRevealFile: onRevealFile,
                            onQuickLook: onQuickLook
                        )
                    }
                }
                .padding()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("No Duplicates Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Great news! No duplicate files were found in the selected folders.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview("Empty") {
    DuplicateGroupList(
        groups: [],
        selectedFileIds: [],
        onToggleFile: { _ in },
        onRevealFile: { _ in },
        onQuickLook: { _ in }
    )
    .frame(width: 600, height: 400)
}

#Preview("With Groups") {
    let groups = MockDataProvider.generatePreviewDuplicates(count: 3)

    return DuplicateGroupList(
        groups: groups,
        selectedFileIds: [],
        onToggleFile: { _ in },
        onRevealFile: { _ in },
        onQuickLook: { _ in }
    )
    .frame(width: 600, height: 500)
}
