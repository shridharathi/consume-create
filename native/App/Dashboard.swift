import SwiftUI
import ServiceManagement

private enum EditSheet: String, Identifiable {
    case apps, calendar, goal, preferences
    var id: String { rawValue }
}

struct Dashboard: View {
    let tracker: ActivityTracker
    @State private var replaySetup = false
    @State private var sheet: EditSheet?

    var body: some View {
        Group {
            if tracker.state.onboardingComplete != true || replaySetup {
                Onboarding(tracker: tracker) { replaySetup = false }
            } else {
                today
            }
        }
        .font(AppTypography.body)
        .frame(minWidth: 720, minHeight: 700)
        .preferredColorScheme(.dark)
        .overlay {
            if let blocked = tracker.blockedActivity {
                BlockNotice(
                    blocked: blocked,
                    dismiss: { tracker.dismissBlockNotice() },
                    turnOffBlocker: { tracker.setAutomaticBlocking(false) }
                )
            }
        }
        .sheet(item: $sheet) { selection in
            switch selection {
            case .apps: RulesSheet(tracker: tracker)
            case .calendar: CalendarSheet(tracker: tracker)
            case .goal: GoalSheet(tracker: tracker)
            case .preferences: PreferencesSheet(tracker: tracker) { sheet = nil; replaySetup = true }
            }
        }
    }

    private var today: some View {
        ZStack {
            BalanceStyle.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    appHeader
                    VStack(alignment: .leading, spacing: 7) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(AppTypography.font(19, weight: .medium))
                            .foregroundStyle(BalanceStyle.secondary)
                        Text(BalanceBattery.headline(for: tracker.state))
                            .font(AppTypography.font(19, weight: .medium))
                            .foregroundStyle(tracker.state.overLimit ? BalanceStyle.alert : BalanceStyle.text)
                    }
                    BalanceBattery(state: tracker.state, prominent: true, showsStatus: false, target: tracker.state.limit) { target in
                        tracker.setLimit(target)
                    }
                        .frame(height: 244)
                    HStack {
                        Spacer()
                        subtleButton("Edit apps & websites", systemImage: "slider.horizontal.3") { sheet = .apps }
                    }
                    HStack(alignment: .top, spacing: 14) {
                        activityColumn(.consume, accent: BalanceStyle.consumeFill(tracker.state))
                        Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
                        activityColumn(.create, accent: .white)
                    }
                    if tracker.state.total(.ignore) > 0 {
                        Button { sheet = .apps } label: {
                            HStack {
                                Image(systemName: "circle.dashed")
                                Text("\(UsageState.duration(tracker.state.total(.ignore))) not counted")
                                Spacer()
                                Text("Sort apps").foregroundStyle(BalanceStyle.text)
                                Image(systemName: "arrow.right")
                            }
                            .font(AppTypography.font(12, weight: .medium))
                            .foregroundStyle(BalanceStyle.secondary)
                            .padding(.vertical, 8)
                        }.buttonStyle(.plain)
                    }
                    if let error = tracker.error { Text(error).font(AppTypography.caption).foregroundStyle(.red) }
                }.padding(30)
            }.scrollIndicators(.hidden)
        }
    }

    private var appHeader: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                iconButton("calendar", help: "Calendar") { sheet = .calendar }
                iconButton(tracker.state.paused ? "play.fill" : "pause.fill", help: tracker.state.paused ? "Resume tracking" : "Pause tracking") { tracker.togglePause() }
                iconButton("gearshape", help: "Preferences") { sheet = .preferences }
            }
        }
    }

    private func activityColumn(_ intention: Intention, accent: Color) -> some View {
        let items = tracker.state.items.values
            .filter { tracker.state.intention(for: $0.id) == intention }
            .sorted { $0.seconds > $1.seconds }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle().fill(accent).frame(width: 7, height: 7)
                Text(intention.rawValue).font(AppTypography.font(14, weight: .semibold)).tracking(0.1)
                Spacer()
                Text(UsageState.duration(tracker.state.total(intention)))
                    .font(AppTypography.font(14, weight: .semibold))
            }
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            ForEach(items.prefix(6)) { item in
                HStack {
                    Text(item.name).lineLimit(1)
                    Spacer()
                    Text(UsageState.duration(item.seconds)).foregroundStyle(BalanceStyle.secondary).monospacedDigit()
                }.font(AppTypography.font(12, weight: .medium))
            }
            if items.isEmpty {
                Text("Nothing here yet").font(AppTypography.font(12)).foregroundStyle(BalanceStyle.secondary).padding(.vertical, 8)
            }
        }
        .foregroundStyle(BalanceStyle.text)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 30, height: 30) }
            .buttonStyle(.plain).foregroundStyle(BalanceStyle.secondary).help(help)
    }

    private func subtleButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: systemImage).font(AppTypography.font(12, weight: .medium)).padding(.horizontal, 4).padding(.vertical, 7) }
            .buttonStyle(.plain).foregroundStyle(BalanceStyle.text)
    }
}

private struct BlockNotice: View {
    let blocked: BlockedActivity
    let dismiss: () -> Void
    let turnOffBlocker: () -> Void

    var body: some View {
        ZStack {
            BalanceStyle.canvas.opacity(0.98).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                Text("\(blocked.name) is paused")
                    .font(AppTypography.font(15, weight: .semibold))
                    .foregroundStyle(BalanceStyle.alert)
                Text("Get back\nto work!")
                    .font(AppTypography.font(54, weight: .semibold))
                    .tracking(-1.5)
                    .lineSpacing(-5)
                Text("Create for about \(blocked.minutesToUnlock) \(blocked.minutesToUnlock == 1 ? "minute" : "minutes") to bring today’s balance back under your target.")
                    .font(AppTypography.font(17))
                    .foregroundStyle(BalanceStyle.secondary)
                    .lineSpacing(5)
                    .frame(maxWidth: 470, alignment: .leading)
                HStack(spacing: 16) {
                    Button("Back to creating") { dismiss() }
                        .buttonStyle(PrimaryAction())
                    Button("Turn off blocker") { turnOffBlocker() }
                        .buttonStyle(.plain)
                        .font(AppTypography.font(14, weight: .medium))
                        .foregroundStyle(BalanceStyle.secondary)
                }
                .padding(.top, 8)
                Text("You can turn it back on anytime in Preferences.")
                    .font(AppTypography.caption)
                    .foregroundStyle(BalanceStyle.secondary)
                    .padding(.top, -10)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(50)
        }
        .transition(.opacity)
        .accessibilityElement(children: .contain)
    }
}

private struct RulesSheet: View {
    let tracker: ActivityTracker
    @Environment(\.dismiss) private var dismiss
    @State private var rules: [String: Intention]
    init(tracker: ActivityTracker) { self.tracker = tracker; _rules = State(initialValue: tracker.state.rules) }
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 5) {
                Text("Customize").font(AppTypography.font(31, weight: .semibold))
                Text("Drag anything to the side that feels right for you.").foregroundStyle(BalanceStyle.secondary)
            }
            ScrollView {
                ClassificationBoard(state: tracker.state, rules: $rules)
                    .frame(maxWidth: 650)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save changes") { tracker.state.rules = rules; tracker.save(forceReload: true); dismiss() }.buttonStyle(PrimaryAction())
            }
        }
        .font(AppTypography.body).foregroundStyle(BalanceStyle.text).padding(28).frame(width: 720, height: 700).background(BalanceStyle.canvas)
    }
}

private struct GoalSheet: View {
    let tracker: ActivityTracker
    @Environment(\.dismiss) private var dismiss
    @State private var ratio: Double
    init(tracker: ActivityTracker) { self.tracker = tracker; _ratio = State(initialValue: tracker.state.limit) }
    var body: some View {
        VStack(spacing: 25) {
            Text("Find your balance.").font(AppTypography.font(31, weight: .semibold))
            RatioEditor(ratio: $ratio)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save my goal") { tracker.setLimit(ratio); dismiss() }.buttonStyle(PrimaryAction())
            }
        }.font(AppTypography.body).foregroundStyle(BalanceStyle.text).padding(35).frame(width: 580).background(BalanceStyle.canvas)
    }
}

private struct PreferencesSheet: View {
    let tracker: ActivityTracker
    let replay: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            Text("Preferences").font(AppTypography.font(29, weight: .semibold))
            Toggle("Automatically block consume apps & websites over my target", isOn: Binding(
                get: { tracker.state.blocksConsumeAutomatically },
                set: { tracker.setAutomaticBlocking($0) }
            ))
            Text("Consume apps are hidden. Consume tabs in connected browsers are replaced with a local pause page until your balance recovers.")
                .font(AppTypography.caption).foregroundStyle(BalanceStyle.secondary)
            Toggle("Gentle reminders when I’m over my goal", isOn: Binding(get: { tracker.state.notifications }, set: { tracker.setNotifications($0) }))
            Toggle("Count websites in Safari & Chrome", isOn: Binding(get: { tracker.state.websites }, set: { tracker.setWebsites($0) }))
            Text(tracker.browserStatus).font(AppTypography.caption).foregroundStyle(BalanceStyle.secondary)
            Toggle("Start when I log in", isOn: Binding(get: { loginEnabled }, set: { enabled in
                do {
                    if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    loginEnabled = SMAppService.mainApp.status == .enabled
                    if enabled && !loginEnabled { tracker.error = "Allow consume:create in System Settings → General → Login Items." }
                } catch { tracker.error = error.localizedDescription }
            }))
            Divider().overlay(.white.opacity(0.1))
            Text("Desktop widget").font(AppTypography.headline)
            Text("Right-click your desktop → Edit Widgets → consume:create. Choose square or wide.")
            Text("Keep the app running. Your menu bar is live; the desktop widget refreshes periodically. Everything stays on this Mac.")
                .font(AppTypography.caption).foregroundStyle(BalanceStyle.secondary)
            if let error = tracker.error { Text(error).font(AppTypography.caption).foregroundStyle(.red) }
            HStack {
                Button("Show welcome again") { dismiss(); replay() }.buttonStyle(.borderless)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(PrimaryAction())
            }
        }
        .font(AppTypography.body).foregroundStyle(BalanceStyle.text).toggleStyle(.switch).padding(30).frame(width: 500).background(BalanceStyle.canvas)
    }
}
