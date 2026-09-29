import DeviceActivity
import _DeviceActivity_SwiftUI
import SwiftUI

/// Sheet that hosts the DeviceActivityReport picker (rendered by the
/// BlockerAppReportExtension). The user taps apps; the extension stores the
/// selection in the shared app group, and the main app maps them to websites.
struct AppUsagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onDone: () -> Void

    init(onDone: @escaping () -> Void = {}) {
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            DeviceActivityReport(
                DeviceActivityReport.Context(rawValue: "App Usage"),
                filter: DeviceActivityFilter(
                    segment: .daily(during: Self.recentInterval)
                )
            )
            .navigationTitle(L10n.string("Auto-add websites"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Done")) {
                        onDone()
                        dismiss()
                    }
                        .fontWeight(.bold)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private static var recentInterval: DateInterval {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return DateInterval(start: start, end: Date())
    }
}
