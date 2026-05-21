import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct SelectionView: View {
    #if canImport(FamilyControls)
    @State private var selection = ShieldStorage.shared.loadSelection()
    @State private var isPickerPresented = false
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground

                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        selectionCard
                        howItWorksCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Apps")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(.cyan)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apps & Websites")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Choose the distractions that should be shielded during quick blocks and scheduled focus windows.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.18))
                        .frame(width: 68, height: 68)
                    Image(systemName: "app.badge")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
            }

            HStack(spacing: 10) {
                statusPill(title: selectionStatusTitle, icon: selectionStatusIcon)
                statusPill(title: "Used by all blocks", icon: "shield.checkered")
            }
        }
        .padding(22)
        .glassCard(cornerRadius: 28)
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Block list", systemImage: "checklist")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Open Apple’s Screen Time picker, then select any apps, categories, or websites you want Blocker App to protect you from.")
                .foregroundStyle(.white.opacity(0.68))

            #if canImport(FamilyControls)
            selectionSummary

            Button {
                isPickerPresented = true
            } label: {
                Label(selectionIsEmpty ? "Choose Apps and Websites" : "Edit Apps and Websites", systemImage: "plus.app.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            .onChange(of: selection) { _, newValue in
                try? ShieldStorage.shared.saveSelection(newValue)
            }
            #else
            Text("FamilyControls picker is available only in the iOS app target.")
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
            Label("How this is used", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                infoRow(icon: "bolt.shield.fill", title: "Quick Block", subtitle: "Instant focus sessions use this same list.")
                infoRow(icon: "calendar.badge.shield", title: "Schedule", subtitle: "Your daily schedule blocks these choices automatically.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    #if canImport(FamilyControls)
    private var selectionSummary: some View {
        HStack(spacing: 12) {
            metricPill(value: selection.applicationTokens.count, label: "Apps", icon: "app.fill")
            metricPill(value: selection.categoryTokens.count, label: "Categories", icon: "square.grid.2x2.fill")
            metricPill(value: selection.webDomainTokens.count, label: "Websites", icon: "globe")
        }
    }

    private var selectionIsEmpty: Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }
    #endif

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
            colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color(red: 0.09, green: 0.10, blue: 0.22), Color(red: 0.13, green: 0.09, blue: 0.25)],
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

    private func metricPill(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.cyan)
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func infoRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.cyan)
                .frame(width: 30, height: 30)
                .background(.cyan.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }
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
