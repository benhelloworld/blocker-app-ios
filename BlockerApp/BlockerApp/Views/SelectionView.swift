import SwiftUI
#if canImport(DeviceActivity)
import DeviceActivity
import _DeviceActivity_SwiftUI
#endif
#if canImport(FamilyControls)
import FamilyControls
#endif

struct SelectionView: View {
    @Environment(\.dismiss) private var dismiss
    #if canImport(FamilyControls)
    @State private var selection = ShieldStorage.shared.loadSelection()
    @State private var isPickerPresented = false
    #endif
    @State private var adultWebFilterEnabled = ShieldStorage.shared.loadAdultWebFilterEnabled()

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground

                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        selectionCard
                        howItWorksCard
                        selectedAppMetadataSyncReport
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 28)
                }
            }
            .navigationTitle(L10n.string("Apps"))
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("blocked-content-done-button")
                }
            }
        }
        .tint(AppActionStyle.turquoise[0])
        .onAppear {
            adultWebFilterEnabled = ShieldStorage.shared.loadAdultWebFilterEnabled()
        }
    }

    @ViewBuilder
    private var selectedAppMetadataSyncReport: some View {
        #if canImport(FamilyControls) && canImport(DeviceActivity)
        if !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty {
            DeviceActivityReport(
                DeviceActivityReport.Context(rawValue: "Selected App Sync"),
                filter: DeviceActivityFilter(
                    segment: .daily(during: Self.recentUsageInterval),
                    applications: selection.applicationTokens,
                    categories: selection.categoryTokens,
                    webDomains: selection.webDomainTokens
                )
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        #endif
    }

    private static var recentUsageInterval: DateInterval {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return DateInterval(start: start, end: Date())
    }


    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("Apps & Websites"))
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text(L10n.string("Choose the distractions that should be shielded during quick blocks and scheduled focus windows."))
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(.mint.opacity(0.18))
                        .frame(width: 68, height: 68)
                    Circle()
                        .stroke(.mint.opacity(0.55), lineWidth: 1)
                        .frame(width: 68, height: 68)
                    Image(systemName: "app.badge")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.mint)
                }
            }
        }
        .padding(22)
        .glassCard(cornerRadius: 28)
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L10n.string("Block list"), systemImage: "checklist")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(L10n.string("Open Apple’s Screen Time picker, then select any apps, categories, or websites you want AntiScroll to protect you from."))
                .foregroundStyle(.white.opacity(0.74))

            #if canImport(FamilyControls)
            selectionSummary
            adultWebsiteToggle

            Button {
                isPickerPresented = true
            } label: {
                Label(selectionIsEmpty ? "Choose Apps and Websites" : "Edit Apps and Websites", systemImage: "plus.app.fill")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: AppActionStyle.turquoise,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: AppActionStyle.turquoise[0].opacity(0.24), radius: 16, y: 7)
            }
            .buttonStyle(PremiumPressButtonStyle())
            .controlSize(.large)
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            .onChange(of: selection) { _, newValue in
                try? ShieldStorage.shared.saveSelection(newValue)
                Task {
                    // Give the report extension a moment to resolve Apple's
                    // privacy-preserving tokens into bundle IDs/display names.
                    try? await Task.sleep(for: .seconds(2))
                    try? await MacBlockPlanSyncService.shared.publishCurrentConfiguration()
                }
            }
            #else
            Text(L10n.string("FamilyControls picker is available only in the iOS app target."))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.string("How this is used"), systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                infoRow(icon: "bolt.shield.fill", title: L10n.string("Quick Block"), subtitle: L10n.string("Instant focus sessions use this same list."), accent: .orange)
                infoRow(icon: "calendar.badge.shield", title: L10n.string("Schedule"), subtitle: L10n.string("Your daily schedule blocks these choices automatically."), accent: .green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    #if canImport(FamilyControls)
    private var selectionSummary: some View {
        HStack(spacing: 12) {
            pickerMetricPill(value: selection.applicationTokens.count, label: L10n.string("Apps"), explanation: L10n.string("Specific apps"), icon: "app.fill", accent: .mint)
            pickerMetricPill(value: selection.categoryTokens.count, label: L10n.string("Categories"), explanation: L10n.string("Whole groups"), icon: "square.grid.2x2.fill", accent: .orange)
            pickerMetricPill(value: selection.webDomainTokens.count, label: L10n.string("Websites"), explanation: L10n.string("Phone sites"), icon: "globe", accent: .blue)
        }
    }

    private func pickerMetricPill(value: Int, label: String, explanation: String, icon: String, accent: Color) -> some View {
        Button {
            AppHaptics.selection()
            isPickerPresented = true
        } label: {
            metricPill(value: value, label: label, explanation: explanation, icon: icon, accent: accent)
        }
        .buttonStyle(PremiumPressButtonStyle())
        .accessibilityHint(L10n.string("Open Apple’s Screen Time picker, then select any apps, categories, or websites you want AntiScroll to protect you from."))
    }

    private var selectionIsEmpty: Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }
    #endif

    private var adultWebsiteToggle: some View {
        Toggle(isOn: $adultWebFilterEnabled) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.headline)
                    .foregroundStyle(adultWebFilterEnabled ? AppActionStyle.turquoise[0] : .white.opacity(0.62))
                    .frame(width: 38, height: 38)
                    .background(
                        (adultWebFilterEnabled ? AppActionStyle.turquoise[0] : Color.white)
                            .opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.string("Porn & adult websites"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(L10n.string("Covers the most common porn sites and many more with Apple’s web filter."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(AppActionStyle.turquoise[0])
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(adultWebFilterEnabled ? AppActionStyle.turquoise[0].opacity(0.48) : .white.opacity(0.13), lineWidth: 1)
        )
        .accessibilityIdentifier("adult-web-filter-toggle")
        .onChange(of: adultWebFilterEnabled) { _, isEnabled in
            #if canImport(FamilyControls) && canImport(ManagedSettings)
            ScheduleService.shared.setAdultWebFilterEnabled(isEnabled)
            #else
            ShieldStorage.shared.saveAdultWebFilterEnabled(isEnabled)
            #endif
        }
    }

    private var selectionStatusTitle: String {
        #if canImport(FamilyControls)
        return selectionIsEmpty ? "Nothing selected" : "Selection ready"
        #else
        return "iOS only"
        #endif
    }

    private var selectionStatusIcon: String {
        #if canImport(FamilyControls)
        return selectionIsEmpty ? "circle.dashed" : "checkmark.circle.fill"
        #else
        return "iphone"
        #endif
    }

    private var appBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func statusPill(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private func metricPill(value: Int, label: String, explanation: String, icon: String, accent: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(accent)
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(explanation)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.50))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.085))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accent.opacity(0.10))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.38), lineWidth: 1)
        )
    }

    private func infoRow(icon: String, title: String, subtitle: String, accent: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.70))
            }
        }
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
