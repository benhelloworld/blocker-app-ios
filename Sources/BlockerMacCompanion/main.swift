import SwiftUI
import AppKit
import BlockerAppCore
import MacCompanionCore

@main
struct BlockerMacCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("AntiScroll Mac Companion", id: "main") {
            MacCompanionView()
                .frame(minWidth: 760, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("AntiScroll Mac Companion", systemImage: "desktopcomputer") {
            MenuBarStatusView()
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            await MacBlockerViewModel.shared.startBackgroundTasks()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@MainActor
final class MacBlockerViewModel: ObservableObject {
    static let shared = MacBlockerViewModel()
    @Published var selectedDomains: Set<String>
    @Published var customDomain = ""
    @Published var durationMinutes = 60
    @Published var activeSession: ImmediateBlockSession?
    @Published var statusMessage = "Ready to protect this Mac."
    @Published var syncMessage = "Automatic sync watches iCloud for iPhone Quick Blocks and schedules — no Mac-side start needed."
    @Published var activeHostsDomains: [String] = []
    @Published var isWorking = false
    @Published var lastPulledPlanDate: Date?
    @Published var isSelectedOnIPhone = false

    private let writer = PrivilegedHostsWriter()
    private let cloudStore: CloudBlockPlanStore? = MacCompanionEntitlements.hasICloudContainer ? CloudBlockPlanStore() : nil
    private let iCloudDriveStore = ICloudDriveBlockPlanStore()
    private let manager = HostsFileManager()
    private let defaults = UserDefaults.standard

    private func syncDebugLog(_ message: String) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("blocker-companion-sync.log")
        let line = "\(Date()) \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path), let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    private enum Keys {
        static let selectedDomains = "BlockerMacCompanion.selectedDomains"
        static let activeSession = "BlockerMacCompanion.activeSession"
    }

    init() {
        let saved = defaults.stringArray(forKey: Keys.selectedDomains)
        selectedDomains = Set(saved ?? [])

        if let data = defaults.data(forKey: Keys.activeSession),
           let session = try? JSONDecoder().decode(ImmediateBlockSession.self, from: data),
           session.isActive() {
            activeSession = session
        } else {
            defaults.removeObject(forKey: Keys.activeSession)
        }
        refreshActiveHosts()
    }

    var selectedDomainList: [String] {
        selectedDomains.sorted()
    }

    var isActive: Bool {
        guard let activeSession else { return false }
        return activeSession.isActive()
    }

    func toggle(_ domain: String) {
        if selectedDomains.contains(domain) {
            selectedDomains.remove(domain)
        } else {
            selectedDomains.insert(domain)
        }
        persistDomains()
    }

    func addCustomDomain() {
        do {
            let cleaned = try manager.sanitizedDomains([customDomain])
            selectedDomains.formUnion(cleaned)
            customDomain = ""
            persistDomains()
            statusMessage = "Added \(cleaned[0])."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func startBlock() {
        guard !isWorking else { return }
        let domains = selectedDomainList
        isWorking = true
        statusMessage = "Approve the Mac administrator prompt to update protected blocking settings."

        Task {
            do {
                try writer.apply(domains: domains)
                let session = ImmediateBlockSession(durationMinutes: durationMinutes)
                activeSession = session
                if let data = try? JSONEncoder().encode(session) {
                    defaults.set(data, forKey: Keys.activeSession)
                }
                refreshActiveHosts()
                statusMessage = "Blocking \(domains.count) websites on this Mac: \(domains.prefix(4).joined(separator: ", "))\(domains.count > 4 ? "…" : "")"
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    func clearBlockIfExpired(now: Date = Date()) {
        guard let session = activeSession, !session.isActive(at: now), !isWorking else { return }
        isWorking = true
        Task {
            do {
                try writer.clearManagedBlock()
                activeSession = nil
                defaults.removeObject(forKey: Keys.activeSession)
                refreshActiveHosts()
                statusMessage = "Mac block finished. Websites are available again."
            } catch {
                statusMessage = "Block expired, but clearing needs admin approval: \(error.localizedDescription)"
            }
            isWorking = false
        }
    }

    func forceClear() {
        guard !isWorking else { return }
        isWorking = true
        statusMessage = "Approve the Mac administrator prompt to clear protected blocking settings."
        Task {
            do {
                try writer.clearManagedBlock()
                activeSession = nil
                defaults.removeObject(forKey: Keys.activeSession)
                refreshActiveHosts()
                statusMessage = "Mac block cleared."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    func refreshActiveHosts() {
        guard let hosts = try? writer.currentHosts() else {
            activeHostsDomains = []
            return
        }
        activeHostsDomains = HostsFileManager.managedDomains(in: hosts)
    }

    func useYouTubePreset() {
        selectedDomains.formUnion(["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"])
        persistDomains()
        statusMessage = "YouTube domains selected. Press Start blocking to apply them to this Mac."
    }

    func pullFromICloud() {
        guard !isWorking else { return }
        Task { await pullFromICloud(applyActiveSession: false) }
    }

    func syncFromICloudIfNeeded(now: Date = Date()) {
        guard !isWorking else { return }
        if let lastPulledPlanDate, now.timeIntervalSince(lastPulledPlanDate) < 8 { return }
        Task { await pullFromICloud(applyActiveSession: true, quiet: true) }
    }

    func runAutoSyncLoop() async {
        while !Task.isCancelled {
            syncFromICloudIfNeeded(now: Date())
            clearBlockIfExpired(now: Date())
            try? await Task.sleep(nanoseconds: 8_000_000_000)
        }
    }

    /// Starts everything the companion needs while running in the background:
    /// register this Mac in the device registry, then sync + expiry forever.
    func startBackgroundTasks() async {
        await DeviceRegistry.upsertCurrentDevice()
        refreshActiveHosts()
        await runAutoSyncLoop()
    }

    @MainActor
    private func pullFromICloud(applyActiveSession: Bool, quiet: Bool = false) async {
        guard !isWorking else { return }
        isWorking = true
        if !quiet { syncMessage = "Checking automatic sync…" }
        do {
            let plan = try await loadSyncedPlan()
            if let plan {
                let effectiveDomains = plan.effectiveDomains
                let protection = plan.activeProtection()
                syncDebugLog("loaded plan schema=\(plan.schemaVersion) domains=\(plan.domains) schedules=\(plan.schedules.count) adultFilter=\(plan.adultWebFilterEnabled) effectiveCount=\(effectiveDomains.count) targets=\(plan.targetDeviceIDs) protection=\(String(describing: protection))")
                guard MacCompanionDevice.planTargetsThisDevice(plan) else {
                    isSelectedOnIPhone = false
                    if applyActiveSession, activeSession != nil || !activeHostsDomains.isEmpty {
                        try? writer.clearManagedBlock()
                        activeSession = nil
                        defaults.removeObject(forKey: Keys.activeSession)
                        refreshActiveHosts()
                    }
                    lastPulledPlanDate = Date()
                    if !quiet { syncMessage = "This Mac is not selected on the iPhone." }
                    isWorking = false
                    return
                }
                isSelectedOnIPhone = true
                selectedDomains = Set(plan.domains)
                durationMinutes = plan.durationMinutes
                persistDomains()
                lastPulledPlanDate = Date()

                if protection?.domains.isEmpty != false {
                    syncDebugLog("phone plan has no Mac domains or adult-site preset; clearing managed Mac block")
                    try? writer.clearManagedBlock()
                    activeSession = nil
                    defaults.removeObject(forKey: Keys.activeSession)
                    refreshActiveHosts()
                    syncMessage = "iPhone selected no Mac websites, so this Mac is not blocking websites."
                    isWorking = false
                    return
                }

                if applyActiveSession, let protection {
                    let expectedDomains = protection.domains
                    let hostsChanged = Set(activeHostsDomains) != Set(expectedDomains)
                    let sessionChanged = activeSession?.start != protection.session.start || activeSession?.durationMinutes != protection.session.durationMinutes
                    if hostsChanged || sessionChanged {
                        syncDebugLog("applying synced protection source=\(protection.source) domains=\(expectedDomains.count)")
                        try writer.apply(domains: expectedDomains)
                        syncDebugLog("writer apply succeeded")
                    }
                    let session = ImmediateBlockSession(start: protection.session.start, durationMinutes: protection.session.durationMinutes)
                    activeSession = session
                    if let data = try? JSONEncoder().encode(session) {
                        defaults.set(data, forKey: Keys.activeSession)
                    }
                    refreshActiveHosts()
                    let sourceLabel = protection.source == .schedule ? "scheduled block" : (protection.source == .combined ? "Quick Block + schedule" : "Quick Block")
                    syncMessage = "Synced from iPhone: \(sourceLabel) active for \(session.remainingMinutes()) min."
                } else {
                    if applyActiveSession {
                        try? writer.clearManagedBlock()
                        activeSession = nil
                        defaults.removeObject(forKey: Keys.activeSession)
                        refreshActiveHosts()
                    }
                    if !quiet {
                        syncMessage = "Pulled \(effectiveDomains.count) domain(s) from iPhone\(plan.adultWebFilterEnabled ? " including the adult-site preset" : "")."
                    }
                }
            } else if !quiet {
                syncMessage = "No iPhone protection plan found yet. Configure apps, websites, or a schedule on the phone."
            }
        } catch {
            syncDebugLog("sync error: \(error.localizedDescription)")
            if !quiet { syncMessage = error.localizedDescription }
        }
        isWorking = false
    }

    private func loadSyncedPlan() async throws -> SyncedMacBlockPlan? {
        var plans: [SyncedMacBlockPlan] = []
        var lastError: Error?
        if let filePlan = try? iCloudDriveStore.loadPlan() { plans.append(filePlan) }
        if let cloudStore {
            do {
                if let cloudPlan = try await cloudStore.loadPlan() { plans.append(cloudPlan) }
            } catch {
                lastError = error
            }
        }
        if let newest = plans.max(by: { $0.updatedAt < $1.updatedAt }) { return newest }
        if let lastError { throw lastError }
        return nil
    }


    func pushToICloud() {
        guard !isWorking else { return }
        guard let cloudStore else {
            syncMessage = "iCloud sync is disabled in this unsigned Desktop build. We need to add CloudKit capability/signing in Xcode for the real sync version."
            return
        }
        isWorking = true
        syncMessage = "Saving to iCloud…"
        let plan = SyncedMacBlockPlan(domains: selectedDomainList, durationMinutes: durationMinutes, targetDeviceIDs: [MacCompanionDevice.currentDeviceID])
        Task {
            do {
                try await cloudStore.savePlan(plan)
                syncMessage = "Saved this Mac selection to iCloud."
            } catch {
                syncMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func persistDomains() {
        defaults.set(selectedDomainList, forKey: Keys.selectedDomains)
    }
}

struct MacCompanionView: View {
    @ObservedObject private var model = MacBlockerViewModel.shared

    private let presets = [15, 30, 60, 120, 240]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.025, green: 0.021, blue: 0.035), Color(red: 0.085, green: 0.061, blue: 0.020)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header(now: context.date)
                        deviceCoverageCard
                        syncCard
                        actionCard(now: context.date)
                        technicalNoteCard
                    }
                    .padding(28)
                }
            }
            .onChange(of: context.date) { now in
                model.clearBlockIfExpired(now: now)
                model.syncFromICloudIfNeeded(now: now)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func header(now: Date) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text("AntiScroll Mac Companion")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("This Mac follows the blocks you start on your iPhone. Choose websites on the phone; the Mac does not keep a separate block list.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: model.isActive ? "lock.shield.fill" : "desktopcomputer")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(model.isActive ? .yellow : .mint)
                .padding(18)
                .background(.white.opacity(0.10), in: Circle())
        }
        .padding(24)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(cardStroke(cornerRadius: 28))
    }

    private var deviceCoverageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Device coverage", systemImage: "rectangle.connected.to.line.below")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 14) {
                coveragePill(
                    title: MacCompanionDevice.currentDeviceName,
                    subtitle: model.isActive ? "Protected now" : (model.isSelectedOnIPhone ? "Selected on iPhone" : "Not selected on iPhone"),
                    icon: "desktopcomputer",
                    color: model.isActive ? .mint : (model.isSelectedOnIPhone ? .cyan : .white.opacity(0.55))
                )
                coveragePill(title: "iPhone", subtitle: "Handled by iOS app", icon: "iphone", color: .mint)
                coveragePill(title: "Sync", subtitle: "Automatic from iPhone", icon: "icloud.fill", color: .cyan)
            }
        }
        .padding(22)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(cardStroke(cornerRadius: 24))
    }

    private var syncCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Account sync", systemImage: "icloud.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("This Mac watches the block plan written by the iPhone app. When this Mac is selected under Device Sync, Quick Blocks and schedules apply here automatically.")
                        .foregroundStyle(.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }


            Text(model.syncMessage)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(22)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(cardStroke(cornerRadius: 24))
    }

    private var domainPickerCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Websites to block")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Choose domains for the Mac companion. Add both root and www versions when needed.")
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Text("\(model.selectedDomains.count) selected")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.yellow, in: Capsule())
            }

            HStack(spacing: 10) {
                Button { model.useYouTubePreset() } label: {
                    Label("Select YouTube domains", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(.bordered)
                .tint(.yellow)
                Text("Current hosts block: \(model.activeHostsDomains.isEmpty ? "nothing active" : model.activeHostsDomains.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                ForEach(MacBlockDomain.starterSet) { item in
                    Button {
                        model.toggle(item.domain)
                    } label: {
                        HStack {
                            Image(systemName: model.selectedDomains.contains(item.domain) ? "checkmark.circle.fill" : "circle")
                            Text(item.domain)
                                .lineLimit(1)
                            Spacer()
                        }
                        .font(.callout.weight(.semibold))
                        .padding(12)
                        .background(model.selectedDomains.contains(item.domain) ? Color.yellow.opacity(0.18) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(model.selectedDomains.contains(item.domain) ? Color.yellow.opacity(0.50) : Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                TextField("Add custom domain, e.g. netflix.com", text: $model.customDomain)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                    .onSubmit { model.addCustomDomain() }
                Button("Add") { model.addCustomDomain() }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .foregroundStyle(.black)
            }
        }
        .padding(22)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(cardStroke(cornerRadius: 24))
    }

    private func actionCard(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.isActive ? "Focus active on this Mac" : "Automatic Mac block")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            if !model.activeHostsDomains.isEmpty {
                Text("Actually active in /etc/hosts: \(model.activeHostsDomains.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.yellow.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let session = model.activeSession, session.isActive(at: now) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.remainingMinutes(at: now) == 1 ? "1 min left" : "\(session.remainingMinutes(at: now)) min left")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)
                    ProgressView(value: session.progress(at: now))
                        .tint(.yellow)
                    Text("Protected until \(session.endTimeLabel(at: now)).")
                        .foregroundStyle(.white.opacity(0.68))
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Waiting for iPhone Quick Block", systemImage: "iphone.gen3.radiowaves.left.and.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Choose websites and this Mac on the iPhone, then start Quick Block. The same website domains will be applied here automatically.")
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack {
                Text(model.statusMessage)
                    .foregroundStyle(.white.opacity(0.68))
                Spacer()
                Button("Clear Mac block") { model.forceClear() }
                    .disabled(model.isWorking)
            }
        }
        .padding(22)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(cardStroke(cornerRadius: 24))
    }

    private var technicalNoteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How this Mac companion works", systemImage: "info.circle.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text("The iPhone is the source of truth. This companion receives the iPhone plan, applies macOS hosts entries plus a temporary pf firewall rule for resolved website IPs, and keeps the block active until the iPhone session ends. Each protected update requires Mac administrator approval. Authorization is used only for that update; no persistent privileged helper is installed.")
                .foregroundStyle(.white.opacity(0.64))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func coveragePill(title: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cardBackground: some ShapeStyle {
        LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.055)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func cardStroke(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(.white.opacity(0.16), lineWidth: 1)
    }

    private func durationLabel(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h"
    }
}

/// Compact status shown in the menu bar extra. The background sync loop runs
/// from the AppDelegate, so this stays live even with all windows closed.
struct MenuBarStatusView: View {
    @ObservedObject private var model = MacBlockerViewModel.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: model.isActive ? "lock.shield.fill" : "desktopcomputer")
                    .font(.title2)
                    .foregroundStyle(model.isActive ? .yellow : .mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.isActive ? "Focus active on this Mac" : "No active block")
                        .font(.headline)
                    if let session = model.activeSession, session.isActive() {
                        Text("\(session.remainingMinutes()) min left")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    } else if !model.activeHostsDomains.isEmpty {
                        Text("Blocking \(model.activeHostsDomains.count) websites")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                Spacer()
            }

            if !model.activeHostsDomains.isEmpty {
                Text("Blocked: \(model.activeHostsDomains.prefix(4).joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.yellow.opacity(0.85))
            }

            Divider()

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open AntiScroll Mac Companion…", systemImage: "macwindow")
            }

            Button {
                model.forceClear()
            } label: {
                Label("Clear Mac block", systemImage: "xmark.shield")
            }
            .disabled(model.isWorking)

            Divider()

            Button("Quit AntiScroll Mac Companion") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}
