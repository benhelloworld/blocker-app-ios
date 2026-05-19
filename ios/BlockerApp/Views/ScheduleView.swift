import SwiftUI

struct ScheduleView: View {
    @State private var start: Date
    @State private var end: Date
    @State private var selectedWeekdays: Set<Int>
    @State private var message: String?

    init() {
        let savedSchedule = ShieldStorage.shared.loadSchedule()
        let calendar = Calendar.current
        _start = State(initialValue: calendar.date(from: DateComponents(hour: savedSchedule.startHour, minute: savedSchedule.startMinute)) ?? Date())
        _end = State(initialValue: calendar.date(from: DateComponents(hour: savedSchedule.endHour, minute: savedSchedule.endMinute)) ?? Date())
        _selectedWeekdays = State(initialValue: savedSchedule.selectedWeekdays.isEmpty ? BlockSchedule.allWeekdays : savedSchedule.selectedWeekdays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Scheduled time")
                } footer: {
                    Text("The scheduled block runs only on the days selected below.")
                }

                Section {
                    weekdaySelector
                        .padding(.vertical, 6)
                } header: {
                    Text("Repeat on")
                } footer: {
                    Text(selectedWeekdays.isEmpty ? "Pick at least one day to save this schedule." : weekdaySummary)
                }

                Button {
                    save()
                } label: {
                    Label("Save Scheduled Block", systemImage: "calendar.badge.shield")
                }
                .disabled(selectedWeekdays.isEmpty)

                if let message {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Schedule")
        }
    }

    private var weekdaySelector: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(BlockSchedule.orderedWeekdays, id: \.weekday) { day in
                Button {
                    toggleWeekday(day.weekday)
                } label: {
                    VStack(spacing: 4) {
                        Text(day.shortName)
                            .font(.headline)
                        Text(day.fullName)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedWeekdays.contains(day.weekday) ? .white : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedWeekdays.contains(day.weekday) ? Color.accentColor : Color.secondary.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selectedWeekdays.contains(day.weekday) ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullName)
                .accessibilityAddTraits(selectedWeekdays.contains(day.weekday) ? [.isSelected] : [])
            }
        }
    }

    private var weekdaySummary: String {
        BlockSchedule(startHour: 0, startMinute: 0, endHour: 0, endMinute: 0, selectedWeekdays: selectedWeekdays).selectedWeekdaySummary
    }

    private func toggleWeekday(_ weekday: Int) {
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }

    private func save() {
        guard !selectedWeekdays.isEmpty else {
            message = "Choose at least one weekday."
            return
        }

        let calendar = Calendar.current
        let startParts = calendar.dateComponents([.hour, .minute], from: start)
        let endParts = calendar.dateComponents([.hour, .minute], from: end)
        let schedule = BlockSchedule(
            startHour: startParts.hour ?? 9,
            startMinute: startParts.minute ?? 0,
            endHour: endParts.hour ?? 17,
            endMinute: endParts.minute ?? 0,
            selectedWeekdays: selectedWeekdays
        )

        do {
            try ScheduleService.shared.startMonitoring(schedule: schedule)
            message = "Scheduled block saved for \(schedule.selectedWeekdaySummary)."
        } catch {
            message = error.localizedDescription
        }
    }
}
