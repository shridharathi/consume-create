import SwiftUI
import AppKit

@main
struct ConsumeCreateApp: App {
    @State private var tracker = ActivityTracker()
    var body: some Scene {
        Window("consume:create", id: "overview") {
            Dashboard(tracker: tracker)
                .onOpenURL { _ in NSApp.activate(ignoringOtherApps: true) }
        }.defaultSize(width: 780, height: 740)
        MenuBarExtra {
            MenuContent(tracker: tracker)
        } label: {
            Label(tracker.state.classified > 0 ? "\(tracker.state.percent):\(100 - tracker.state.percent)" : "consume:create",
                  systemImage: tracker.state.paused ? "pause.circle" : tracker.state.overLimit ? "battery.25percent" : "battery.75percent")
        }.menuBarExtraStyle(.window)
    }
}

struct MenuContent: View {
    let tracker: ActivityTracker
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BalanceBattery(state: tracker.state, edgeToEdge: true).frame(height: 155)
            Button(tracker.state.onboardingComplete == true ? "See my day" : "Let’s get started") { openWindow(id: "overview"); NSApp.activate(ignoringOtherApps: true) }
                .buttonStyle(.borderedProminent)
            HStack {
                Button(tracker.state.paused ? "Resume" : "Pause") { tracker.togglePause() }
                Spacer()
                Button("Quit") { tracker.save(forceReload: true); NSApp.terminate(nil) }
            }
        }.font(AppTypography.body).padding(20).frame(width: 330).background(BalanceStyle.canvas).preferredColorScheme(.dark)
    }
}
