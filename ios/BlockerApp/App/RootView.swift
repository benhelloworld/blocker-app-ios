import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            StatusView()
                .tabItem { Label("Status", systemImage: "shield") }

            SelectionView()
                .tabItem { Label("Apps", systemImage: "app.badge") }

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
        }
    }
}
