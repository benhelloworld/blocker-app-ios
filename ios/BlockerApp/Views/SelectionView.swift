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
            VStack(spacing: 20) {
                Text("Choose the apps, categories, and websites you want to shield during your focus window.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                #if canImport(FamilyControls)
                Button("Choose Apps and Websites") {
                    isPickerPresented = true
                }
                .buttonStyle(.borderedProminent)
                .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
                .onChange(of: selection) { _, newValue in
                    try? ShieldStorage.shared.saveSelection(newValue)
                }
                #else
                Text("FamilyControls picker is available only in the iOS app target.")
                #endif
            }
            .padding()
            .navigationTitle("Apps")
        }
    }
}
