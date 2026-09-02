import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct ScheduleView: View {
    @EnvironmentObject private var premiumStore: PremiumEntitlementStore
    let onboardingTarget: String?

    @State private var showingForm = false
    @State private var savedSchedule = ShieldStorage.shared.loadSchedule()
    @State private var scheduleEnabled = ShieldStorage.shared.loadScheduleEnabled()
    @State private var syncDevices: [SyncDevice] = []
    @State private var message: String?

    init(onboardingTarget: String? = nil) {
        self.onboardingTarget = onboardingTarget
    }

    private var hasSavedSchedule: Bool {
        savedSchedule != .defaultFocus || scheduleEnabled
    }

    var body: some View {
        Group {
            if premiumStore.isPremium {
                scheduleContent
            } else {
                PremiumUpsellView(trigger: .scheduledBlocking)
            }
        }
        .tint(AppActionStyle.turquoise[0])
        .onAppear {
            savedSchedule = ShieldStorage.shared.loadSchedule()
            scheduleEnabled = ShieldStorage.shared.loadScheduleEnabled()
            refreshSyncDevices()
        }
        .sheet(isPresented: $showingForm) {
            ScheduleFormView(
                initialSchedule: hasSavedSchedule ? savedSchedule : nil,
                onSaved: { schedule, enabled in
                    savedSchedule = schedule
                    scheduleEnabled = enabled
                    showingForm = false
                }
            )
        }
    }

    private var scheduleContent: some View {
        NavigationStack {
            ZStack {
                appBackground

                ScrollView {
                    VStack(spacing: 18) {
                        heroCard

                        if hasSavedSchedule {
                            activeScheduleCard
                        } else {
                            emptyStateCard
                        }
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 150)
                }

                bottomTabScrim
            }
            .navigationTitle(L10n.string("Schedule"))
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var bottomTabScrim: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.72), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var heroCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.mint)
                .frame(width: 48, height: 48)
                .background(.mint.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            explanatoryText("Automatic blocking windows that protect the same apps and websites every week.")

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Saved schedule summary

    private var activeScheduleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(L10n.string("Schedule enabled"), systemImage: "calendar.badge.checkmark")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { scheduleEnabled },
                    set: { newValue in toggleScheduleEnabled(newValue) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(AppActionStyle.turquoise[0])
                .accessibilityLabel(L10n.string("Schedule enabled"))
                .accessibilityValue(scheduleEnabled ? L10n.string("On") : L10n.string("Off"))
            }

            schedulePeriodsSummary

            if let blocklistName {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .font(.caption)
                        .foregroundStyle(.mint)
                    Text(String(format: L10n.string("Blocklist: %@"), blocklistName))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(spacing: 10) {
                Image(systemName: "rectangle.connected.to.line.below")
                    .font(.caption)
                    .foregroundStyle(AppActionStyle.turquoise[0])
                Text(String(format: L10n.string("Protected on: %@"), protectedDeviceSummary(for: savedSchedule)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                showingForm = true
            } label: {
                Label(L10n.string("Edit Schedule"), systemImage: "pencil")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: AppActionStyle.turquoise, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
                    .shadow(color: AppActionStyle.turquoise[0].opacity(0.24), radius: 16, y: 7)
            }
            .buttonStyle(PremiumPressButtonStyle())

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
        .id("Schedule")
        .onboardingHighlight("Schedule")
    }

    private func scheduleMetric(icon: String, value: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.14), in: Circle())
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var schedulePeriodsSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(savedSchedule.summaryGroups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(weekdaySummary(group.weekdays))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(.mint)
                        Text(String(
                            format: L10n.string("%@ – %@"),
                            timeLabel(hour: group.period.startHour, minute: group.period.startMinute),
                            timeLabel(hour: group.period.endHour, minute: group.period.endMinute)
                        ))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        if group.period.crossesMidnight {
                            Text(L10n.string("Next day"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func weekdaySummary(_ weekdays: [Int]) -> String {
        let ordered = BlockSchedule.orderedWeekdays.filter { weekdays.contains($0.weekday) }
        if Set(weekdays) == BlockSchedule.allWeekdays,
           let first = ordered.first,
           let last = ordered.last {
            return String(
                format: L10n.string("%@ – %@"),
                L10n.string(first.fullName),
                L10n.string(last.fullName)
            )
        }
        return ordered.map { L10n.string($0.fullName) }.joined(separator: ", ")
    }

    private var blocklistName: String? {
        guard let id = savedSchedule.selectedBlocklistID else { return nil }
        return ShieldStorage.shared.loadBlocklist(id: id)?.name
    }

    private func timeLabel(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return formatter.string(from: Calendar.current.date(from: components) ?? Date())
    }

    private func toggleScheduleEnabled(_ isEnabled: Bool) {
        AppHaptics.selection()
        scheduleEnabled = isEnabled
        if isEnabled {
            do {
                try ScheduleService.shared.startMonitoring(schedule: savedSchedule)
                message = L10n.string("Schedule turned on.")
            } catch {
                scheduleEnabled = false
                ShieldStorage.shared.saveScheduleEnabled(false)
                message = error.localizedDescription
            }
        } else {
            ScheduleService.shared.stopMonitoring()
            message = L10n.string("Schedule turned off.")
        }
    }

    private func refreshSyncDevices() {
        Task {
            if let devices = try? await SyncDeviceRegistryService.fetchDevices() {
                await MainActor.run { syncDevices = devices }
            }
        }
    }

    private func protectedDeviceSummary(for schedule: BlockSchedule) -> String {
        let ids = schedule.effectiveProtectedDeviceIDs(defaultRemoteDeviceIDs: ShieldStorage.shared.loadSelectedMacDeviceIDs())
        var names: [String] = []
        if ids.contains(MacBlockDevicePreset.currentDeviceID.lowercased()) {
            names.append(L10n.string("This iPhone"))
        }
        let matchingDevices = syncDevices.filter {
            ids.contains($0.id.lowercased()) && $0.id.lowercased() != MacBlockDevicePreset.currentDeviceID.lowercased()
        }
        names.append(contentsOf: matchingDevices.map(\.displayName))
        let remainingCount = max(0, ids.count - names.count)
        if remainingCount > 0 {
            names.append(String(format: L10n.string("%d other device(s)"), remainingCount))
        }
        return names.isEmpty ? L10n.string("No devices") : names.joined(separator: " • ")
    }

    // MARK: - Empty state

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(.mint.opacity(0.14))
                    .frame(width: 64, height: 64)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.mint)
            }

            Text(L10n.string("No schedule yet"))
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(L10n.string("Create a recurring block so focus happens automatically — no need to start it every time."))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showingForm = true
            } label: {
                Label(L10n.string("Create Schedule"), systemImage: "plus")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: AppActionStyle.turquoise, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
                    .shadow(color: AppActionStyle.turquoise[0].opacity(0.24), radius: 16, y: 7)
            }
            .buttonStyle(PremiumPressButtonStyle())
            .accessibilityIdentifier("create-schedule-button")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .glassCard(cornerRadius: 26)
        .id("Schedule")
        .onboardingHighlight("Schedule")
    }

    private var appBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func explanatoryText(_ copy: String) -> some View {
        Text(L10n.string(copy))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.66))
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Schedule form (create/edit sheet)

private struct ScheduleFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var premiumStore: PremiumEntitlementStore

    let initialSchedule: BlockSchedule?
    let onSaved: (BlockSchedule, Bool) -> Void

    @State private var periodsByWeekday: [Int: [ScheduleTimePeriod]]
    @State private var selectedBlocklistID: UUID?
    @State private var selectedProtectedDeviceIDs: Set<String>
    @State private var syncDevices: [SyncDevice] = []
    @State private var message: String?
    #if canImport(FamilyControls)
    @State private var blocklists = ShieldStorage.shared.loadBlocklists()
    @State private var showingCreateBlocklist = false
    @State private var draftBlocklistName = ""
    @State private var draftSelection = FamilyActivitySelection()
    @State private var isDraftPickerPresented = false
    #endif

    init(initialSchedule: BlockSchedule?, onSaved: @escaping (BlockSchedule, Bool) -> Void) {
        self.initialSchedule = initialSchedule
        self.onSaved = onSaved
        let schedule = initialSchedule ?? ShieldStorage.shared.loadSchedule()
        _periodsByWeekday = State(initialValue: schedule.periodsByWeekday)
        _selectedBlocklistID = State(initialValue: schedule.selectedBlocklistID)
        _selectedProtectedDeviceIDs = State(initialValue: schedule.effectiveProtectedDeviceIDs(defaultRemoteDeviceIDs: ShieldStorage.shared.loadSelectedMacDeviceIDs()))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        blocklistCard
                        timeCard
                        protectedDevicesCard
                        saveCard
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Cancel")) { dismiss() }
                }
            }
            #if canImport(FamilyControls)
            .sheet(isPresented: $showingCreateBlocklist) {
                createBlocklistSheet
            }
            #endif
        }
        .tint(AppActionStyle.turquoise[0])
        .task { await refreshProtectedDevices() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(initialSchedule == nil ? L10n.string("New schedule") : L10n.string("Edit schedule"))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(L10n.string("Choose a blocklist, weekday time periods, and protected devices."))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Step 1: blocklist
    private var blocklistCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader(number: 1, title: L10n.string("Choose a blocklist"), icon: "list.bullet.rectangle.portrait.fill")

            #if canImport(FamilyControls)
            if blocklists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("No blocklists yet"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L10n.string("Create your first list of apps, categories, and websites for scheduled blocks."))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.62))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(blocklists) { blocklist in
                        blocklistRow(blocklist)
                    }
                }
            }

            Button {
                draftBlocklistName = ""
                draftSelection = FamilyActivitySelection()
                showingCreateBlocklist = true
            } label: {
                Label(L10n.string("Create a blocklist"), systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(PremiumPressButtonStyle())
            #else
            Text(L10n.string("Blocklists are available only in the iOS app target."))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    #if canImport(FamilyControls)
    private func blocklistRow(_ blocklist: NamedBlocklist) -> some View {
        Button {
            selectedBlocklistID = blocklist.id
            do {
                try ShieldStorage.shared.saveScheduledSelection(blocklist.selection)
            } catch {
                message = error.localizedDescription
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selectedBlocklistID == blocklist.id ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(selectedBlocklistID == blocklist.id ? .mint : .white.opacity(0.74))

                VStack(alignment: .leading, spacing: 5) {
                    Text(blocklist.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L10n.string("Custom app and website list"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.64))
                }
                Spacer()
            }
            .padding(14)
            .background(selectedBlocklistID == blocklist.id ? Color.mint.opacity(0.16) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(selectedBlocklistID == blocklist.id ? Color.mint.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(PremiumPressButtonStyle())
    }

    private var createBlocklistSheet: some View {
        NavigationStack {
            ZStack {
                appBackground
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(L10n.string("Create Blocklist"))
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.string("Blocklist name"))
                                .font(.headline)
                                .foregroundStyle(.white)
                            TextField(L10n.string("Social without YouTube"), text: $draftBlocklistName)
                                .textInputAutocapitalization(.words)
                                .padding(14)
                                .foregroundStyle(.white)
                                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Label(L10n.string("Blocked apps & websites"), systemImage: "app.badge")
                                .font(.headline)
                                .foregroundStyle(.white)

                            HStack(spacing: 10) {
                                metricPill(value: draftSelection.applicationTokens.count, label: "Apps")
                                metricPill(value: draftSelection.categoryTokens.count, label: "Categories")
                                metricPill(value: draftSelection.webDomainTokens.count, label: "Websites")
                            }

                            Button {
                                isDraftPickerPresented = true
                            } label: {
                                Label(L10n.string("Add or remove apps"), systemImage: "plus.circle")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(PremiumPressButtonStyle())
                            .familyActivityPicker(isPresented: $isDraftPickerPresented, selection: $draftSelection)
                        }
                        .padding(18)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Cancel")) { showingCreateBlocklist = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Create")) { createBlocklist() }
                        .disabled(draftBlocklistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftSelection.applicationTokens.isEmpty && draftSelection.categoryTokens.isEmpty && draftSelection.webDomainTokens.isEmpty)
                }
            }
        }
    }

    private func metricPill(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func createBlocklist() {
        let blocklist = NamedBlocklist(name: draftBlocklistName, selection: draftSelection)
        do {
            try ShieldStorage.shared.upsertBlocklist(blocklist)
            try ShieldStorage.shared.saveScheduledSelection(blocklist.selection)
            blocklists = ShieldStorage.shared.loadBlocklists()
            selectedBlocklistID = blocklist.id
            showingCreateBlocklist = false
            message = L10n.string("Blocklist created.")
        } catch {
            message = error.localizedDescription
        }
    }
    #endif

    // Step 2: flexible weekday periods
    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(number: 2, title: L10n.string("Time periods by weekday"), icon: "clock.fill")

            Text(L10n.string("Add one or more blocking periods to each day. Overnight periods end on the next day."))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(BlockSchedule.orderedWeekdays, id: \.weekday) { day in
                weekdayPeriodsEditor(day)
            }

            Text(String(
                format: L10n.string("%d of %d weekday periods used"),
                totalPeriodCount,
                BlockSchedule.maximumRecurringMonitorCount
            ))
            .font(.caption.weight(.semibold))
            .foregroundStyle(totalPeriodCount >= BlockSchedule.maximumRecurringMonitorCount ? .orange : .white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
        .id("Schedule")
        .onboardingHighlight("Schedule")
    }

    private func weekdayPeriodsEditor(_ day: (weekday: Int, shortName: String, fullName: String)) -> some View {
        let periods = periodsByWeekday[day.weekday] ?? []
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.string(day.fullName))
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(periods.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(periods.isEmpty ? .white.opacity(0.48) : AppActionStyle.turquoise[0])
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.08), in: Capsule())
            }

            ForEach(periods) { period in
                timePeriodRow(weekday: day.weekday, period: period)
            }

            Button {
                addTimePeriod(to: day.weekday)
            } label: {
                Label(L10n.string("Add time period"), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppActionStyle.turquoise[0])
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .buttonStyle(PremiumPressButtonStyle())
            .disabled(totalPeriodCount >= BlockSchedule.maximumRecurringMonitorCount)
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func timePeriodRow(weekday: Int, period: ScheduleTimePeriod) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                DatePicker(
                    L10n.string("Start"),
                    selection: periodTimeBinding(weekday: weekday, periodID: period.id, isStart: true),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .colorScheme(.dark)

                Text("—")
                    .foregroundStyle(.white.opacity(0.5))

                DatePicker(
                    L10n.string("End"),
                    selection: periodTimeBinding(weekday: weekday, periodID: period.id, isStart: false),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .colorScheme(.dark)

                Spacer(minLength: 4)

                Button(role: .destructive) {
                    removeTimePeriod(period.id, from: weekday)
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red.opacity(0.82))
                        .frame(width: 34, height: 34)
                        .background(.red.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("Remove time period"))
            }

            if period.crossesMidnight {
                Label(L10n.string("Ends the next day"), systemImage: "moon.stars.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var totalPeriodCount: Int {
        periodsByWeekday.values.reduce(0) { $0 + $1.count }
    }

    private func addTimePeriod(to weekday: Int) {
        guard totalPeriodCount < BlockSchedule.maximumRecurringMonitorCount else { return }
        let last = periodsByWeekday[weekday]?.last
        let startMinutes = last?.endTotalMinutes ?? 9 * 60
        let endMinutes = (startMinutes + 60) % (24 * 60)
        let period = ScheduleTimePeriod(
            startHour: startMinutes / 60,
            startMinute: startMinutes % 60,
            endHour: endMinutes / 60,
            endMinute: endMinutes % 60
        )
        periodsByWeekday[weekday, default: []].append(period)
        periodsByWeekday[weekday]?.sort { $0.startTotalMinutes < $1.startTotalMinutes }
    }

    private func removeTimePeriod(_ id: UUID, from weekday: Int) {
        periodsByWeekday[weekday]?.removeAll { $0.id == id }
        if periodsByWeekday[weekday]?.isEmpty == true {
            periodsByWeekday.removeValue(forKey: weekday)
        }
    }

    private func periodTimeBinding(weekday: Int, periodID: UUID, isStart: Bool) -> Binding<Date> {
        Binding(
            get: {
                guard let period = periodsByWeekday[weekday]?.first(where: { $0.id == periodID }) else { return Date() }
                let hour = isStart ? period.startHour : period.endHour
                let minute = isStart ? period.startMinute : period.endMinute
                return Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
            },
            set: { newValue in
                guard let index = periodsByWeekday[weekday]?.firstIndex(where: { $0.id == periodID }) else { return }
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                if isStart {
                    periodsByWeekday[weekday]?[index].startHour = parts.hour ?? 0
                    periodsByWeekday[weekday]?[index].startMinute = parts.minute ?? 0
                } else {
                    periodsByWeekday[weekday]?[index].endHour = parts.hour ?? 0
                    periodsByWeekday[weekday]?[index].endMinute = parts.minute ?? 0
                }
            }
        )
    }

    // Step 3: repeat days (kept as a compact helper for accessibility and previews)
    private var selectedWeekdays: Set<Int> { Set(periodsByWeekday.keys) }

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader(number: 3, title: L10n.string("Choose repeat days"), icon: "calendar")

            weekdaySelector

            Text(selectedWeekdays.isEmpty ? L10n.string("Pick at least one day to save this schedule.") : String(format: L10n.string("Active on %@."), weekdaySummary))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.74))
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
                    VStack(spacing: 3) {
                        Text(L10n.string(day.shortName))
                            .font(.caption.weight(.bold))
                        Text(L10n.string(day.fullName))
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(selectedWeekdays.contains(day.weekday) ? .black : .white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedWeekdays.contains(day.weekday) ? AnyShapeStyle(AppActionStyle.turquoise[0]) : AnyShapeStyle(.white.opacity(0.10)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selectedWeekdays.contains(day.weekday) ? .white.opacity(0.35) : .white.opacity(0.14), lineWidth: 1)
                    )
                }
                .buttonStyle(PremiumPressButtonStyle())
                .accessibilityLabel(day.fullName)
                .accessibilityAddTraits(selectedWeekdays.contains(day.weekday) ? [.isSelected] : [])
            }
        }
    }

    // Step 4: devices
    private var protectedDevicesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader(number: 3, title: L10n.string("Protected devices"), icon: "rectangle.connected.to.line.below")

            Text(L10n.string("Choose where this schedule should activate automatically."))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            protectedDeviceRow(
                id: MacBlockDevicePreset.currentDeviceID,
                name: L10n.string("This iPhone"),
                subtitle: L10n.string("Screen Time blocks on this iPhone"),
                systemImage: "iphone"
            )

            ForEach(connectedScheduleDevices) { device in
                protectedDeviceRow(
                    id: device.id,
                    name: device.displayName,
                    subtitle: device.deviceType == "mac"
                        ? L10n.string("Websites block automatically in the Mac Companion")
                        : L10n.string("Follows this schedule automatically"),
                    systemImage: device.systemImage
                )
            }

            if connectedScheduleDevices.isEmpty {
                Text(L10n.string("No other connected devices yet. Connect devices in Settings → Device Sync."))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if selectedProtectedDeviceIDs.isEmpty {
                Text(L10n.string("Pick at least one protected device."))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
        .accessibilityIdentifier("schedule-protected-devices-section")
    }

    private var connectedScheduleDevices: [SyncDevice] {
        var seen = Set<String>()
        return syncDevices.filter {
            let id = $0.id.lowercased()
            return id != MacBlockDevicePreset.currentDeviceID.lowercased() && seen.insert(id).inserted
        }
    }

    private func protectedDeviceRow(id: String, name: String, subtitle: String, systemImage: String) -> some View {
        let normalizedID = id.lowercased()
        let isSelected = selectedProtectedDeviceIDs.contains(normalizedID)
        return Button {
            AppHaptics.selection()
            if isSelected {
                selectedProtectedDeviceIDs.remove(normalizedID)
            } else {
                selectedProtectedDeviceIDs.insert(normalizedID)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? AppActionStyle.turquoise[0] : .white.opacity(0.55))
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(14)
            .background(isSelected ? AppActionStyle.turquoise[0].opacity(0.14) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isSelected ? AppActionStyle.turquoise[0].opacity(0.44) : .white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(PremiumPressButtonStyle())
        .accessibilityIdentifier("schedule-device-\(normalizedID)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @MainActor
    private func refreshProtectedDevices() async {
        if let devices = try? await SyncDeviceRegistryService.fetchDevices() {
            syncDevices = devices
        }
    }

    // Step 5: save
    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader(number: 4, title: L10n.string("Save"), icon: "checkmark.circle.fill")

            Button {
                save()
            } label: {
                Label(L10n.string("Save Scheduled Block"), systemImage: "calendar.badge.shield")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(PremiumPressButtonStyle())
            .background(
                LinearGradient(colors: AppActionStyle.turquoise, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
            .shadow(color: AppActionStyle.turquoise[0].opacity(0.24), radius: 16, y: 7)
            .controlSize(.large)
            .disabled(selectedWeekdays.isEmpty || selectedProtectedDeviceIDs.isEmpty)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(message.localizedCaseInsensitiveContains("saved") ? .white.opacity(0.72) : .red)
            } else {
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private func stepHeader(number: Int, title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.black))
                .foregroundStyle(.black)
                .frame(width: 26, height: 26)
                .background(AppActionStyle.turquoise[0], in: Circle())
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.white)
        }
    }

    private func timePickerRow(title: String, icon: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.mint)
                .frame(width: 34, height: 34)
                .background(.mint.opacity(0.16), in: Circle())

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
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func toggleWeekday(_ weekday: Int) {
        AppHaptics.selection()
        if periodsByWeekday[weekday]?.isEmpty == false {
            periodsByWeekday.removeValue(forKey: weekday)
        } else {
            periodsByWeekday[weekday] = [ScheduleTimePeriod(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)]
        }
    }

    private var weekdaySummary: String {
        BlockSchedule(periodsByWeekday: periodsByWeekday).selectedWeekdaySummary
    }

    private func save() {
        guard premiumStore.isPremium else {
            message = L10n.string("Premium unlocks scheduled and recurring blocks.")
            return
        }

        guard !selectedWeekdays.isEmpty else {
            message = L10n.string("Choose at least one weekday.")
            return
        }

        guard !selectedProtectedDeviceIDs.isEmpty else {
            message = L10n.string("Pick at least one protected device.")
            return
        }

        let schedule = BlockSchedule(
            periodsByWeekday: periodsByWeekday,
            selectedBlocklistID: selectedBlocklistID,
            protectedDeviceIDs: selectedProtectedDeviceIDs
        )

        if let issue = schedule.validationIssue() {
            message = ScheduleServiceError.invalidSchedule(issue).localizedDescription
            return
        }

        do {
            try ScheduleService.shared.startMonitoring(schedule: schedule)
            onSaved(schedule, true)
        } catch {
            message = error.localizedDescription
        }
    }

    private var appBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 26) -> some View {
        background(
            LinearGradient(
                colors: [.white.opacity(0.13), .white.opacity(0.055)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.mint.opacity(0.12), lineWidth: 1)
        )
    }
}
