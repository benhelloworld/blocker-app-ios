import SwiftUI

struct RootView: View {
    @State private var showLaunchSplash = true
    private let slogan = AppLaunchSlogan.primary

    var body: some View {
        ZStack {
            mainTabs

            if showLaunchSplash {
                LaunchSplashView(slogan: slogan)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(10)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    showLaunchSplash = false
                }
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            StatusView()
                .tabItem { Label("Status", systemImage: "shield") }

            SelectionView()
                .tabItem { Label("Apps", systemImage: "app.badge") }

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }

            FocusProgressView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            FocusModesView()
                .tabItem { Label("Modes", systemImage: "sparkles") }
        }
    }
}

private struct LaunchSplashView: View {
    let slogan: AppLaunchSlogan
    @State private var glow = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.035, green: 0.045, blue: 0.09), Color(red: 0.10, green: 0.08, blue: 0.20), Color(red: 0.03, green: 0.09, blue: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.cyan.opacity(glow ? 0.26 : 0.12))
                        .frame(width: 92, height: 92)
                        .blur(radius: 2)
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.cyan)
                }

                VStack(spacing: 8) {
                    Text(slogan.title)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(slogan.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}
