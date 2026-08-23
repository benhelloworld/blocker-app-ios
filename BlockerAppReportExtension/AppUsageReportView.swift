import SwiftUI

/// The picker UI hosted inside the report extension. Users tap apps (and
/// optionally categories) they want to auto-block as websites on all devices.
struct AppUsageReportView: View {
    let snapshot: AppUsageSnapshot
    @State private var selectedBundleIDs: Set<String>
    @State private var selectedCategories: Set<String>

    init(snapshot: AppUsageSnapshot) {
        self.snapshot = snapshot
        _selectedBundleIDs = State(initialValue: ReportShared.loadSelectedBundleIDs())
        _selectedCategories = State(initialValue: ReportShared.loadSelectedCategoryNames())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if snapshot.apps.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(snapshot.apps) { app in
                            row(
                                title: app.displayName,
                                subtitle: app.bundleIdentifier,
                                isOn: selectedBundleIDs.contains(app.bundleIdentifier)
                            ) {
                                toggle(app.bundleIdentifier, in: &selectedBundleIDs, save: ReportShared.saveSelectedBundleIDs)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.85))
        .foregroundColor(.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Block their websites too")
                .font(.headline.weight(.bold))
            Text("Pick apps — the matching website is blocked on all synced devices automatically.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.title2)
                .foregroundColor(.white.opacity(0.5))
            Text("No app usage available yet. Use your device a little, then check back.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func row(title: String, subtitle: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? .yellow : .white.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(10)
            .background(isOn ? Color.yellow.opacity(0.16) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ id: String, in set: inout Set<String>, save: (Set<String>) -> Void) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
        save(set)
        let selectedNames = Set(snapshot.apps.filter { selectedBundleIDs.contains($0.bundleIdentifier) }.map(\.displayName))
        ReportShared.saveSelectedDisplayNames(selectedNames)
    }
}
