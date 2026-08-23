import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FamilyControls)
import FamilyControls
#endif

/// Central place for everything that used to crowd the Status screen:
/// subscription management, device sync, Screen Time details, help, privacy,
/// restore purchases, reset progress, and language.
struct SettingsView: View {
    @EnvironmentObject private var premiumStore: PremiumEntitlementStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var authorization = AuthorizationService()
    @State private var showingUpsell = false
    @State private var showingShortcutInstructions = false
    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground

                ScrollView {
                    VStack(spacing: 18) {
                        subscriptionSection
                        deviceSyncSection
                        screenTimeSection
                        helpSection
                        privacySection
                        accountSection
                        languageSection
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 40)
                }
            }
            .navigationTitle(L10n.string("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingUpsell) {
                PremiumUpsellView(trigger: .advancedFeatures) {
                    showingUpsell = false
                }
            }
            .sheet(isPresented: $showingShortcutInstructions) {
                ShortcutSetupInstructionsView()
            }
            .alert(L10n.string("Reset progress?"), isPresented: $showingResetConfirmation) {
                Button(L10n.string("Reset"), role: .destructive) {
                    try? ShieldStorage.shared.saveFocusStats(FocusStats())
                }
                Button(L10n.string("Cancel"), role: .cancel) {}
            } message: {
                Text(L10n.string("This clears your focus stats only. Blocking settings stay untouched."))
            }
        }
        .tint(AppActionStyle.turquoise[0])
        .onAppear {
            authorization.refresh()
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

    // MARK: - Subscription

    private var subscriptionSection: some View {
        sectionCard(title: L10n.string("Subscription"), icon: "crown.fill", accent: .yellow) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.yellow.opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: premiumStore.isPremium ? "crown.fill" : "lock.open.fill")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(premiumStore.isPremium ? L10n.string("Premium Active") : L10n.string("Free"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(premiumStore.isPremium ? L10n.string("All focus tools unlocked") : L10n.string("Free Quick Blocks are capped at 2 hours. Premium removes the limit."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()
            }

            Button {
                showingUpsell = true
            } label: {
                Label(premiumStore.isPremium ? L10n.string("Manage Plan") : L10n.string("Buy Premium"), systemImage: premiumStore.isPremium ? "creditcard.fill" : "crown.fill")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: AppActionStyle.yellowGold, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
            }
            .buttonStyle(PremiumPressButtonStyle())
            .accessibilityIdentifier("settings-premium-button")
        }
    }

    // MARK: - Device sync

    private var deviceSyncSection: some View {
        NavigationLink {
            DeviceSyncView()
        } label: {
            sectionCard(title: L10n.string("Device Sync"), icon: "desktopcomputer", accent: .cyan, chevron: true) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.string("iPhone + Macs"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(L10n.string("Pick devices that follow your blocks and manage websites sent to Mac."))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text(L10n.string("iCloud"))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan, in: Capsule())
                }
            }
        }
        .buttonStyle(PremiumPressButtonStyle())
        .accessibilityIdentifier("device-sync-settings-button")
    }

    // MARK: - Screen Time

    private var screenTimeSection: some View {
        NavigationLink {
            ScreenTimeDetailsView(authorization: authorization)
        } label: {
            sectionCard(title: L10n.string("Screen Time"), icon: authorization.isAuthorized ? "checkmark.circle.fill" : "lock.shield", accent: authorization.isAuthorized ? .mint : .yellow, chevron: true) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(authorization.isAuthorized ? L10n.string("Access granted") : L10n.string("Needs access"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(authorization.isAuthorized
                             ? L10n.string("AntiScroll can shield selected apps and websites.")
                             : L10n.string("Allow Screen Time access to start blocking."))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
            }
        }
        .buttonStyle(PremiumPressButtonStyle())
    }

    // MARK: - Help & setup

    private var helpSection: some View {
        sectionCard(title: L10n.string("Help and setup"), icon: "questionmark.circle.fill", accent: .mint) {
            VStack(spacing: 10) {
                NavigationLink {
                    FocusFlowGuideView()
                } label: {
                    settingsRow(icon: "point.3.connected.trianglepath.dotted", accent: .mint, title: L10n.string("How the app works"), subtitle: L10n.string("The focus flow in four short steps."))
                }
                .buttonStyle(PremiumPressButtonStyle())

                Button {
                    showingShortcutInstructions = true
                } label: {
                    settingsRow(icon: "link.badge.plus", accent: .yellow, title: L10n.string("Shortcut pause setup"), subtitle: L10n.string("Open the full Shortcuts setup guide."))
                }
                .buttonStyle(PremiumPressButtonStyle())
            }
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        sectionCard(title: L10n.string("Privacy"), icon: "lock.shield.fill", accent: .green) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("Your choices stay on-device and are saved privately in the app group."))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.string("AntiScroll cannot read your messages, browsing history, or private app content."))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        sectionCard(title: L10n.string("Account"), icon: "person.crop.circle", accent: .orange) {
            VStack(spacing: 10) {
                Button {
                    Task {
                        await premiumStore.restorePurchases()
                    }
                } label: {
                    settingsRow(icon: "arrow.clockwise.circle.fill", accent: .orange, title: L10n.string("Restore Purchases"), subtitle: L10n.string("Restore Premium on this device."))
                }
                .buttonStyle(PremiumPressButtonStyle())

                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    settingsRow(icon: "arrow.counterclockwise", accent: .red, title: L10n.string("Reset progress"), subtitle: L10n.string("Clears focus stats only."))
                }
                .buttonStyle(PremiumPressButtonStyle())
            }
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        sectionCard(title: L10n.string("Language"), icon: "globe", accent: .blue) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.string("App language"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(L10n.string("Follows your iPhone language automatically."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
            }
        }
    }

    // MARK: - Reusable pieces

    private func sectionCard<Content: View>(title: String, icon: String, accent: Color, chevron: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
    }

    private func settingsRow(icon: String, accent: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Device Sync detail

struct DeviceSyncView: View {
    @Environment(\.dismiss) private var dismiss

    private let macCompanionDownloadURL = URL(string: "https://github.com/benhelloworld/blocker-app-ios/releases/latest")!

    @State private var syncDevices: [SyncDevice] = []
    @State private var devicesLoaded = false
    @State private var selectedMacDeviceIDs = Set(ShieldStorage.shared.loadSelectedMacDeviceIDs())
    @State private var syncedMacDomains = Set(ShieldStorage.shared.loadMacBlockDomains())
    @State private var autoWebsiteDomains = AutoWebsiteSync.shared.autoDomains
    @State private var customSyncedMacDomain = ""
    @State private var showingSyncedMacWebsites = false
    @State private var showingAppUsagePicker = false
    @State private var showingMacConnectionGuide = false
    @State private var macDownloadLinkCopied = false
    @State private var message: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    currentDeviceCard
                    connectedDevicesCard
                    macConnectionGuideCard
                    websitesCard
                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .safeAreaPadding(.bottom, 40)
            }
        }
        .navigationTitle(L10n.string("Device Sync"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            refreshSyncDevices()
        }
        .sheet(isPresented: $showingSyncedMacWebsites) {
            syncedMacWebsitesSheet
        }
        .sheet(isPresented: $showingAppUsagePicker) {
            AppUsagePickerView {
                autoWebsiteDomains = AutoWebsiteSync.shared.autoDomains
                pushDeviceSelection()
            }
        }
        .sheet(isPresented: $showingMacConnectionGuide) {
            macConnectionGuideSheet
        }
    }

    private var currentDeviceCard: some View {
        let own = SyncDevice(
            id: SyncDeviceRegistryService.currentDeviceID,
            deviceType: SyncDeviceRegistryService.currentDeviceType,
            displayName: SyncDeviceRegistryService.currentDisplayName,
            lastSeen: Date()
        )

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "iphone")
                    .font(.headline)
                    .foregroundStyle(.mint)
                Text(L10n.string("Current device"))
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(isProtectedNow(deviceID: own.id) ? L10n.string("Protected now") : L10n.string("Ready"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(isProtectedNow(deviceID: own.id) ? .black : .white.opacity(0.72))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isProtectedNow(deviceID: own.id) ? Color.mint : Color.white.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 12) {
                Image(systemName: own.systemImage)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.84))
                VStack(alignment: .leading, spacing: 3) {
                    Text(own.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(L10n.string("Use Screen Time protection on this device"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
            }
            .padding(14)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
    }

    private var connectedDevicesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "desktopcomputer")
                    .font(.headline)
                    .foregroundStyle(.cyan)
                Text(L10n.string("Connected devices"))
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(selectedMacDeviceIDs.isEmpty ? L10n.string("Off") : "\(selectedMacDeviceIDs.count)")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(selectedMacDeviceIDs.isEmpty ? .white.opacity(0.72) : .black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedMacDeviceIDs.isEmpty ? Color.white.opacity(0.12) : Color.cyan, in: Capsule())
            }

            Text(L10n.string("Pick which devices should follow your iPhone Quick Blocks and schedules."))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.64))

            ForEach(connectedDevices) { device in
                Button {
                    toggleMacDevice(device.id)
                } label: {
                    deviceRow(device)
                }
                .buttonStyle(PremiumPressButtonStyle())
            }

            if connectedDevices.isEmpty {
                Text(L10n.string("No Macs connected yet. Open the AntiScroll Mac Companion on your Mac to register it."))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
    }

    private var macConnectionGuideCard: some View {
        Button {
            showingMacConnectionGuide = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer.and.arrow.down")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.string("How to connect a Mac"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L10n.string("Install the Companion, approve once, then select your Mac."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.cyan.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(PremiumPressButtonStyle())
        .accessibilityIdentifier("mac-connection-guide-button")
    }

    private var macConnectionGuideSheet: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 7) {
                            Label(L10n.string("Mac connection guide"), systemImage: "desktopcomputer")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text(L10n.string("Connect in a few quick steps. Your iPhone controls what gets blocked."))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.68))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 12) {
                            Label(L10n.string("Download Mac Companion"), systemImage: "desktopcomputer.and.arrow.down")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text(L10n.string("Copy this link and paste it into a browser on your Mac:"))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)

                            Text(macCompanionDownloadURL.absoluteString.replacingOccurrences(of: "https://", with: ""))
                                .font(.caption.monospaced())
                                .foregroundStyle(.cyan)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.cyan.opacity(0.28), lineWidth: 1))

                            Button {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = macCompanionDownloadURL.absoluteString
                                #endif
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    macDownloadLinkCopied = true
                                }
                            } label: {
                                Label(
                                    L10n.string(macDownloadLinkCopied ? "Link copied" : "Copy link"),
                                    systemImage: macDownloadLinkCopied ? "checkmark.circle.fill" : "doc.on.doc.fill"
                                )
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: AppActionStyle.turquoise, startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
                            }
                            .buttonStyle(PremiumPressButtonStyle())
                            .accessibilityIdentifier("copy-mac-companion-link-button")

                            Text(L10n.string("Requires macOS 13 or later."))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.56))
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cyan.opacity(0.09), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.cyan.opacity(0.30), lineWidth: 1))

                        macConnectionStep(number: 1, icon: "square.and.arrow.down", title: "Open the Mac Companion", detail: "Install and open AntiScroll Mac Companion on your Mac.")
                        macConnectionStep(number: 2, icon: "icloud", title: "Use the same Apple Account", detail: "Make sure your iPhone and Mac use the same Apple Account and iCloud Drive is on.")
                        macConnectionStep(number: 3, icon: "lock.shield", title: "Approve administrator access", detail: "When Mac blocking changes, approve the administrator prompt so the Companion can update protected system settings.")
                        macConnectionStep(number: 4, icon: "checkmark.circle", title: "Select your Mac here", detail: "Return to Device Sync and tap your Mac under Connected devices.")
                        macConnectionStep(number: 5, icon: "menubar.rectangle", title: "Keep the Companion running", detail: "Leave it in the Mac menu bar. Selected websites will follow your iPhone Quick Blocks automatically.")

                        VStack(alignment: .leading, spacing: 5) {
                            Label(L10n.string("Mac not showing up?"), systemImage: "arrow.clockwise")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.cyan)
                            Text(L10n.string("Keep the Mac Companion open, then return to this page to refresh the device list."))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.66))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cyan.opacity(0.09), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.cyan.opacity(0.25), lineWidth: 1))
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.string("How to connect a Mac"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) { showingMacConnectionGuide = false }
                }
            }
        }
        .accessibilityIdentifier("mac-connection-guide-sheet")
    }

    private func macConnectionStep(number: Int, icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 34, height: 34)
                Text("\(number)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 5) {
                Label(L10n.string(title), systemImage: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(L10n.string(detail))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.13), lineWidth: 1))
    }

    private var websitesCard: some View {
        Button {
            showingSyncedMacWebsites = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe.badge.chevron.backward")
                    .font(.headline)
                    .foregroundStyle(.cyan)
                    .frame(width: 34, height: 34)
                    .background(Color.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.string("Websites sent to Mac"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L10n.string("Apps become websites automatically; schedules follow too."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(2)
                }

                Spacer()

                Text("\(syncedMacDomains.count + autoWebsiteDomains.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.cyan, in: Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .padding(14)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.cyan.opacity(0.24), lineWidth: 1))
        }
        .buttonStyle(PremiumPressButtonStyle())
    }

    private var syncedMacWebsitesSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(L10n.string("Websites sent to Mac"), systemImage: "globe.badge.chevron.backward")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text(L10n.string("Your iPhone sends these websites and schedules to every selected Mac automatically."))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    // Auto-added websites from the user's apps
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.string("Automatically from your apps"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(L10n.string("Websites of the apps you picked are added automatically. No manual step needed."))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                            Spacer()
                            Button {
                                showingAppUsagePicker = true
                            } label: {
                                Label(L10n.string("Pick apps"), systemImage: "plus.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.cyan, in: Capsule())
                            }
                            .buttonStyle(PremiumPressButtonStyle())
                        }

                        if autoWebsiteDomains.isEmpty {
                            Text(L10n.string("No apps picked yet — tap Pick apps to choose from your recently used apps."))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 8)], spacing: 8) {
                                ForEach(autoWebsiteDomains, id: \.self) { domain in
                                    HStack(spacing: 7) {
                                        Image(systemName: "wand.and.stars")
                                            .font(.caption2)
                                        Text(domain)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.cyan.opacity(0.30), lineWidth: 1))
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text(L10n.string("Manual websites"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 8)], spacing: 8) {
                        ForEach(MacBlockDomainPreset.starterDomains, id: \.self) { domain in
                            Button {
                                toggleSyncedMacDomain(domain)
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: syncedMacDomains.contains(domain) ? "checkmark.circle.fill" : "circle")
                                    Text(domain)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(syncedMacDomains.contains(domain) ? Color.cyan.opacity(0.18) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(syncedMacDomains.contains(domain) ? Color.cyan.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 1))
                            }
                            .buttonStyle(PremiumPressButtonStyle())
                        }
                    }

                    HStack(spacing: 10) {
                        TextField(L10n.string("Add website, e.g. netflix.com"), text: $customSyncedMacDomain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                            .onSubmit(addCustomSyncedMacDomain)
                        Button(L10n.string("Add")) { addCustomSyncedMacDomain() }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color.black, Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle(L10n.string("Mac websites"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Done")) { showingSyncedMacWebsites = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: showingAppUsagePicker) { _, shown in
            if !shown {
                autoWebsiteDomains = AutoWebsiteSync.shared.autoDomains
            }
        }
    }

    /// This device plus every device found in the CloudKit registry.
    private var displaySyncDevices: [SyncDevice] {
        var seen = Set<String>()
        var result: [SyncDevice] = []
        let own = SyncDevice(
            id: SyncDeviceRegistryService.currentDeviceID,
            deviceType: SyncDeviceRegistryService.currentDeviceType,
            displayName: SyncDeviceRegistryService.currentDisplayName,
            lastSeen: Date()
        )
        for device in [own] + syncDevices where seen.insert(device.id).inserted {
            result.append(device)
        }
        return result
    }

    /// Devices other than this one (Macs and iPads in the registry).
    private var connectedDevices: [SyncDevice] {
        displaySyncDevices.filter { $0.id != SyncDeviceRegistryService.currentDeviceID }
    }

    private func deviceRow(_ device: SyncDevice) -> some View {
        let isSelected = selectedMacDeviceIDs.contains(device.id)
        return HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.bold))
                .foregroundStyle(isSelected ? Color.cyan : Color.white.opacity(0.58))
            Image(systemName: device.systemImage)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.84))
            VStack(alignment: .leading, spacing: 3) {
                Text(device.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(deviceSubtitle(for: device))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
            if isProtectedNow(deviceID: device.id) {
                Text(L10n.string("Protected now"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.mint, in: Capsule())
            }
        }
        .padding(14)
        .background(isSelected ? Color.cyan.opacity(0.16) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isSelected ? Color.cyan.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 1))
    }

    private func isProtectedNow(deviceID: String, now: Date = Date()) -> Bool {
        let normalizedID = deviceID.lowercased()
        if let quickBlock = ShieldStorage.shared.loadActiveImmediateSession(now: now), quickBlock.isActive(at: now) {
            if normalizedID == SyncDeviceRegistryService.currentDeviceID.lowercased() { return true }
            if selectedMacDeviceIDs.contains(normalizedID) { return true }
        }

        guard ShieldStorage.shared.loadScheduleEnabled() else { return false }
        let schedule = ShieldStorage.shared.loadSchedule()
        guard ActiveScheduledBlockWindow.activeWindow(for: schedule, now: now) != nil else { return false }
        return schedule.effectiveProtectedDeviceIDs(defaultRemoteDeviceIDs: ShieldStorage.shared.loadSelectedMacDeviceIDs())
            .contains(normalizedID)
    }

    private func deviceSubtitle(for device: SyncDevice) -> String {
        if device.deviceType == "mac" {
            return L10n.string("Websites are blocked on this Mac automatically")
        }
        return L10n.string("Follows your blocks on this device automatically")
    }

    /// Registers this device in the CloudKit registry and loads the device list.
    private func refreshSyncDevices() {
        guard !devicesLoaded else { return }
        devicesLoaded = true
        Task {
            try? await SyncDeviceRegistryService.upsertCurrentDevice()
            if let devices = try? await SyncDeviceRegistryService.fetchDevices() {
                await MainActor.run { syncDevices = devices }
            }
        }
    }

    /// Immediately pushes the current selection to the synced devices.
    private func pushDeviceSelection() {
        let domains = AutoWebsiteSync.shared.mergedDomains(withManual: Array(syncedMacDomains))
        let ids = ShieldStorage.shared.loadSelectedMacDeviceIDs()
        Task {
            try? await MacBlockPlanSyncService.shared.saveCurrentSelection(
                domains: domains,
                durationMinutes: 60,
                targetDeviceIDs: ids,
                adultWebFilterEnabled: ShieldStorage.shared.loadAdultWebFilterEnabled()
            )
        }
    }

    private func toggleMacDevice(_ id: String) {
        AppHaptics.selection()
        if selectedMacDeviceIDs.contains(id) {
            selectedMacDeviceIDs.remove(id)
        } else {
            selectedMacDeviceIDs.insert(id)
        }
        ShieldStorage.shared.saveSelectedMacDeviceIDs(Array(selectedMacDeviceIDs))
        pushDeviceSelection()
    }

    private func toggleSyncedMacDomain(_ domain: String) {
        AppHaptics.selection()
        if syncedMacDomains.contains(domain) {
            syncedMacDomains.remove(domain)
        } else {
            syncedMacDomains.insert(domain)
        }
        ShieldStorage.shared.saveMacBlockDomains(Array(syncedMacDomains))
        pushDeviceSelection()
    }

    private func addCustomSyncedMacDomain() {
        let cleaned = MacBlockDomainPreset.sanitized([customSyncedMacDomain])
        guard let domain = cleaned.first else {
            message = L10n.string("Enter a valid website like youtube.com.")
            return
        }
        syncedMacDomains.insert(domain)
        customSyncedMacDomain = ""
        ShieldStorage.shared.saveMacBlockDomains(Array(syncedMacDomains))
        pushDeviceSelection()
        message = String(format: L10n.string("Added %@. It is syncing now."), domain)
        AppHaptics.success()
    }
}

// MARK: - Screen Time details

struct ScreenTimeDetailsView: View {
    @ObservedObject var authorization: AuthorizationService

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    let explainer = ScreenTimePermissionExplainer.standard

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: authorization.isAuthorized ? "checkmark.circle.fill" : "lock.shield")
                                .font(.headline)
                                .foregroundStyle(authorization.isAuthorized ? .green : .yellow)
                            Text(L10n.string(explainer.title))
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                        }

                        if authorization.isAuthorized {
                            Label(L10n.string("Screen Time access is on"), systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.mint)
                        } else {
                            PermissionExplanationRows(explainer: explainer)

                            Button {
                                Task { await authorization.requestAuthorization() }
                            } label: {
                                Label(L10n.string(explainer.ctaTitle), systemImage: "lock.shield")
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(colors: AppActionStyle.turquoise, startPoint: .topLeading, endPoint: .bottomTrailing),
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    )
                                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
                            }
                            .buttonStyle(PremiumPressButtonStyle())

                            if let error = authorization.lastError {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))

                    let coverage = BlockCoverageExplainer.standard
                    VStack(alignment: .leading, spacing: 12) {
                        Label(coverage.title, systemImage: "desktopcomputer")
                            .font(.headline)
                            .foregroundStyle(.yellow)
                        ForEach(coverage.bullets, id: \.self) { bullet in
                            Label(L10n.string(bullet), systemImage: "info.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.76))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Label(L10n.string(coverage.websiteReminder), systemImage: "globe")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.yellow.opacity(0.26), lineWidth: 1))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
                }
                .padding()
                .safeAreaPadding(.bottom, 40)
            }
        }
        .navigationTitle(L10n.string("Screen Time"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Focus flow guide

struct FocusFlowGuideView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    CoreFlowCard(currentTab: "Status", headline: L10n.string("Your focus flow"), subtitle: L10n.string("A simple flow: choose what to protect, start a block, automate it, then review your progress."))

                    FeatureOnboardingCard(
                        eyebrow: L10n.string("Start here"),
                        title: L10n.string("Quick Block is the main action"),
                        subtitle: L10n.string("Pick a length, choose your block strength, then press Start Focus."),
                        systemImage: "bolt.shield.fill",
                        accent: .mint,
                        steps: [
                            FeatureGuideStep(title: L10n.string("Choose a length"), message: L10n.string("Pick a preset like Reset, Deep Work, Study, or Sleep — or set a custom duration."), systemImage: "timer", accent: .mint),
                            FeatureGuideStep(title: L10n.string("Press start"), message: L10n.string("AntiScroll applies only the apps and websites you selected."), systemImage: "play.fill", accent: .mint),
                            FeatureGuideStep(title: L10n.string("Stay committed"), message: L10n.string("An active longer block cannot be replaced by a shorter one."), systemImage: "lock.shield.fill", accent: .orange)
                        ]
                    )
                }
                .padding()
                .safeAreaPadding(.bottom, 40)
            }
        }
        .navigationTitle(L10n.string("How the app works"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
