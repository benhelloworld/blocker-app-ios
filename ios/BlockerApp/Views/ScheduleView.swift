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
            ZStack {
                appBackground

                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        timeCard
                        repeatCard
                        saveCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Schedule")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(.cyan)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Schedule")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Set an automatic focus window that shields your selected apps and websites on the days you choose.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.18))
                        .frame(width: 68, height: 68)
                    Image(systemName: "calendar.badge.shield")
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
            }

            HStack(spacing: 10) {
                statusPill(title: selectedWeekdays.isEmpty ? "Needs days" : weekdaySummary, icon: selectedWeekdays.isEmpty ? "exclamationmark.circle" : "repeat")
            }
        }
        .padding(22)
        .glassCard(cornerRadius: 28)
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Scheduled time", systemImage: "clock.fill")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("The scheduled block runs only during this window.")
                .foregroundStyle(.white.opacity(0.68))

            VStack(spacing: 12) {
                timePickerRow(title: "Start", icon: "sunrise.fill", selection: $start)
                timePickerRow(title: "End", icon: "moon.fill", selection: $end)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Repeat on", systemImage: "calendar")
                .font(.title2.bold())
                .foregroundStyle(.white)

            weekdaySelector

            Text(selectedWeekdays.isEmpty ? "Pick at least one day to save this schedule." : "Active on \(weekdaySummary).")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                save()
            } label: {
                Label("Save Scheduled Block", systemImage: "calendar.badge.shield")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedWeekdays.isEmpty)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(message.localizedCaseInsensitiveContains("saved") ? .white.opacity(0.72) : .red)
            } else {
                Text("This uses the Apps tab selection and updates your Screen Time schedule.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.64))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
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
                    .foregroundStyle(selectedWeekdays.contains(day.weekday) ? .white : .white.opacity(0.72))
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedWeekdays.contains(day.weekday) ? Color.cyan.opacity(0.32) : Color.white.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(selectedWeekdays.contains(day.weekday) ? Color.cyan.opacity(0.80) : Color.white.opacity(0.14), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullName)
                .accessibilityAddTraits(selectedWeekdays.contains(day.weekday) ? [.isSelected] : [])
            }
        }
    }

    private var appBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color(red: 0.09, green: 0.10, blue: 0.22), Color(red: 0.13, green: 0.09, blue: 0.25)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var weekdaySummary: String {
        BlockSchedule(startHour: 0, startMinute: 0, endHour: 0, endMinute: 0, selectedWeekdays: selectedWeekdays).selectedWeekdaySummary
    }

    private func timePickerRow(title: String, icon: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.cyan)
                .frame(width: 34, height: 34)
                .background(.cyan.opacity(0.14), in: Circle())

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
        }
        .padding(14)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func statusPill(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.12), in: Capsule())
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

private extension View {
    func glassCard(cornerRadius: CGFloat = 26) -> some View {
        background(
            LinearGradient(
                colors: [.white.opacity(0.16), .white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}
