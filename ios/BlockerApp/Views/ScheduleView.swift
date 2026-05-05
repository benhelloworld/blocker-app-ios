import SwiftUI

struct ScheduleView: View {
    @State private var start = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var end = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)

                Button("Save Daily Block") {
                    save()
                }

                if let message {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Schedule")
        }
    }

    private func save() {
        let calendar = Calendar.current
        let startParts = calendar.dateComponents([.hour, .minute], from: start)
        let endParts = calendar.dateComponents([.hour, .minute], from: end)
        let schedule = BlockSchedule(
            startHour: startParts.hour ?? 9,
            startMinute: startParts.minute ?? 0,
            endHour: endParts.hour ?? 17,
            endMinute: endParts.minute ?? 0
        )

        do {
            try ScheduleService.shared.startMonitoring(schedule: schedule)
            message = "Daily block saved."
        } catch {
            message = error.localizedDescription
        }
    }
}
