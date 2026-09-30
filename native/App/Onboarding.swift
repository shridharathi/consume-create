import SwiftUI

struct Onboarding: View {
    let tracker: ActivityTracker
    var onFinish: () -> Void
    @State private var step = 0
    @State private var rules: [String: Intention]
    @State private var ratio: Double

    init(tracker: ActivityTracker, onFinish: @escaping () -> Void) {
        self.tracker = tracker
        self.onFinish = onFinish
        _rules = State(initialValue: IntentionItem.startingRules(tracker.state.rules))
        _ratio = State(initialValue: tracker.state.limit)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 9) {
                    Text("consume:create").font(AppTypography.font(18, weight: .semibold)).tracking(0.1)
                }
                Spacer()
                if step < 3 {
                    HStack(spacing: 6) {
                        ForEach(0..<3) { index in
                            Capsule().fill(index == step ? BalanceStyle.accent : Color.white.opacity(0.13))
                                .frame(width: index == step ? 25 : 7, height: 7)
                        }
                    }.accessibilityLabel("Step \(step + 1) of 3")
                }
            }.padding(.bottom, 25)
            ScrollView {
                VStack(spacing: 22) {
                    switch step {
                    case 0: welcome
                    case 1: classification
                    case 2: goal
                    default: complete
                    }
                }.frame(maxWidth: .infinity).padding(.bottom, 10)
            }.scrollIndicators(.hidden)
            HStack {
                if step > 0 && step < 3 { Button("← Back") { advance(to: step - 1) }.buttonStyle(.plain).foregroundStyle(BalanceStyle.secondary) }
                Spacer()
                if step < 3 { Text("\(step + 1) of 3").font(AppTypography.caption).foregroundStyle(BalanceStyle.secondary) }
                Button(actionLabel) {
                    if step == 3 {
                        tracker.state.rules = rules
                        tracker.state.limit = ratio
                        tracker.state.onboardingComplete = true
                        tracker.save(forceReload: true)
                        onFinish()
                    } else { advance(to: step + 1) }
                }.buttonStyle(PrimaryAction()).keyboardShortcut(.defaultAction)
            }.padding(.top, 18)
        }.font(AppTypography.body).padding(32)
            .foregroundStyle(BalanceStyle.text)
            .background(BalanceStyle.canvas)
    }

    private var actionLabel: String {
        ["Let’s get started →", "That looks like me →", "Looks good →", "Start my balance →"][step]
    }

    private func advance(to step: Int) { withAnimation(.easeInOut(duration: 0.2)) { self.step = step } }

    private var welcome: some View {
        VStack(spacing: 25) {
            Spacer().frame(height: 12)
            HStack(spacing: 0) {
                VStack(spacing: 13) {
                    Image(systemName: "play.rectangle").font(.system(size: 35, weight: .light))
                    Text("consume").font(AppTypography.font(17, weight: .medium)).tracking(0.1)
                }.foregroundStyle(BalanceStyle.ink).frame(width: 155, height: 170).background(BalanceStyle.accent)
                VStack(spacing: 13) {
                    Image(systemName: "pencil.and.outline").font(.system(size: 35, weight: .light))
                    Text("create").font(AppTypography.font(17, weight: .medium)).tracking(0.1)
                }.foregroundStyle(BalanceStyle.ink).frame(width: 155, height: 170).background(.white)
            }.clipShape(RoundedRectangle(cornerRadius: 35)).rotationEffect(.degrees(-3)).padding(.vertical, 15)
                .shadow(color: BalanceStyle.accent.opacity(0.12), radius: 35, y: 15)
            Text("Welcome!").font(AppTypography.font(46, weight: .semibold))
            Text("A little less scrolling.\nA little more making.")
                .font(AppTypography.font(25, weight: .medium)).multilineTextAlignment(.center)
            Text("Pick what you consume, pick what you create,\nand find a balance that feels right for you.")
                .font(AppTypography.font(16)).foregroundStyle(BalanceStyle.secondary).multilineTextAlignment(.center).lineSpacing(5)
            Label("Just for you. Everything stays on your Mac.", systemImage: "lock")
                .font(AppTypography.caption).foregroundStyle(BalanceStyle.secondary).padding(.top, 8)
        }
    }

    private var classification: some View {
        VStack(spacing: 18) {
            heading("What’s consume? What’s create?", subtitle: "We made a starting list. Move things where they belong for you.")
            ClassificationBoard(state: tracker.state, rules: $rules)
        }
    }

    private var goal: some View {
        VStack(spacing: 34) {
            heading("Find your balance.", subtitle: "How much room do you want to leave for making?")
            RatioEditor(ratio: $ratio).padding(.horizontal, 30)
            Label("Your widget turns red when consume goes above \(Int((ratio * 100).rounded()))%.", systemImage: "circle.lefthalf.filled")
                .font(AppTypography.callout).foregroundStyle(BalanceStyle.secondary).padding(.top, 10)
        }.padding(.top, 10)
    }

    private var complete: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark").font(.system(size: 35, weight: .medium))
                .foregroundStyle(BalanceStyle.ink).frame(width: 90, height: 90).background(BalanceStyle.accent, in: Circle()).padding(.top, 30)
            heading("All done!", subtitle: "\(Int((ratio * 100).rounded()))% consume. \(100 - Int((ratio * 100).rounded()))% create. A little more intention.")
            VStack(alignment: .leading, spacing: 14) {
                Label("Your balance lives in the menu bar.", systemImage: "menubar.rectangle")
                Label("For your desktop: right-click → Edit Widgets → consume:create.", systemImage: "rectangle.on.rectangle")
            }.font(AppTypography.callout).padding(22).background(BalanceStyle.surface, in: RoundedRectangle(cornerRadius: 20))
            VStack(spacing: 12) {
                Button(tracker.state.websites ? "Website tracking is on ✓" : "Connect Safari & Chrome") { tracker.setWebsites(!tracker.state.websites) }
                    .buttonStyle(.bordered)
                Text("To count websites, connect your browser and allow access when macOS asks.")
                    .font(AppTypography.caption).foregroundStyle(BalanceStyle.secondary).multilineTextAlignment(.center)
                Button(tracker.state.notifications ? "Gentle reminders are on ✓" : "Let me know when I’m over my goal") { tracker.setNotifications(!tracker.state.notifications) }
                    .buttonStyle(.borderless)
                Text("Both are optional. You can turn them on later.").font(AppTypography.caption2).foregroundStyle(BalanceStyle.secondary)
            }
            if let error = tracker.error { Text(error).font(AppTypography.caption).foregroundStyle(.red) }
        }
    }

    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 9) {
            Text(title).font(AppTypography.font(32, weight: .semibold))
            Text(subtitle).font(AppTypography.font(15)).foregroundStyle(BalanceStyle.secondary).multilineTextAlignment(.center)
        }.padding(.top, 7)
    }
}
