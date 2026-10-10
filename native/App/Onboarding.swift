import SwiftUI

struct Onboarding: View {
    let tracker: ActivityTracker
    var onFinish: () -> Void
    @State private var step = 0
    @State private var rules: [String: Intention]
    @State private var ratio: Double
    @State private var previewFloat = false

    init(tracker: ActivityTracker, onFinish: @escaping () -> Void) {
        self.tracker = tracker
        self.onFinish = onFinish
        _rules = State(initialValue: IntentionItem.startingRules(tracker.state.rules))
        _ratio = State(initialValue: tracker.state.limit)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step == 0 {
                    Text("consume:create").font(AppTypography.display(15, bold: true))
                }
                Spacer()
                if step < 3 {
                    HStack(spacing: 5) {
                        ForEach(0..<3) { index in
                            Rectangle().fill(index == step ? BalanceStyle.accent : Color.white.opacity(0.18))
                                .frame(width: index == step ? 20 : 6, height: 3)
                        }
                    }.accessibilityLabel("Step \(step + 1) of 3")
                }
            }.padding(.bottom, 18)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    switch step {
                    case 0: welcome
                    case 1: classification
                    case 2: goal
                    default: complete
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14)
            }.scrollIndicators(.hidden)
            HStack {
                if step > 0 && step < 3 { Button("← back") { advance(to: step - 1) }.buttonStyle(.plain).foregroundStyle(BalanceStyle.secondary) }
                Spacer()
                if step < 3 { Text("\(step + 1) / 3").font(AppTypography.caption).foregroundStyle(BalanceStyle.secondary) }
                Button(actionLabel) {
                    if step == 3 {
                        tracker.state.rules = rules
                        tracker.state.limit = ratio
                        tracker.state.onboardingComplete = true
                        tracker.save(forceReload: true)
                        onFinish()
                    } else { advance(to: step + 1) }
                }.buttonStyle(PrimaryAction()).keyboardShortcut(.defaultAction)
            }.padding(.top, 16)
        }.font(AppTypography.body).padding(34)
            .foregroundStyle(BalanceStyle.text)
            .background(BalanceStyle.canvas)
    }

    private var actionLabel: String {
        ["Let’s get started →", "Sounds like me →", "Set your balance →", "Start my balance →"][step]
    }

    private func advance(to step: Int) { withAnimation(.easeInOut(duration: 0.2)) { self.step = step } }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 24)
            Text("less scroll, more build!")
                .font(AppTypography.display(30, bold: true))
                .lineSpacing(3)
            Text("Set your ideal consume:create ratio and block apps while you create.")
                .font(AppTypography.font(16))
                .foregroundStyle(BalanceStyle.secondary)
                .lineSpacing(5)
                .frame(maxWidth: 460, alignment: .leading)
            welcomeAppPreview.padding(.top, 68)
            Spacer(minLength: 28)
        }
    }

    private var welcomeAppPreview: some View {
        let consumeApps = IntentionItem.suggestions.filter { $0.id == "web:youtube.com" || $0.id == "web:instagram.com" || $0.id == "web:x.com" }
        let createApps = IntentionItem.suggestions.filter { $0.id == "com.openai.codex" || $0.id == "notion.id" || $0.id == "com.microsoft.Word" }

        return VStack(spacing: 12) {
            ZStack {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        Rectangle().fill(BalanceStyle.accent)
                            .frame(width: geometry.size.width * 0.43)
                        Rectangle().fill(BalanceStyle.create)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    Rectangle()
                        .fill(BalanceStyle.ink.opacity(0.82))
                        .frame(width: 3, height: geometry.size.height)
                        .offset(x: geometry.size.width * 0.43 - 1.5)
                }

                HStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ForEach(consumeApps) { AppBadge(item: $0) }
                    }
                    .frame(maxWidth: .infinity)
                    .offset(x: -18)

                    HStack(spacing: 12) {
                        ForEach(createApps) { AppBadge(item: $0) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 22)
            }
            .frame(width: 440, height: 106)
            .shadow(color: .black.opacity(0.42), radius: 24, y: 18)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("40%")
                        .font(AppTypography.font(18, weight: .medium))
                    Text("consume")
                        .font(AppTypography.font(12, weight: .medium))
                }
                .foregroundStyle(BalanceStyle.accent)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("60%")
                        .font(AppTypography.font(18, weight: .medium))
                    Text("create")
                        .font(AppTypography.font(12, weight: .medium))
                }
                .foregroundStyle(BalanceStyle.secondary)
            }
            .frame(width: 440)
        }
        // The bar and both metrics are one plane, so all three inherit identical perspective and tilt.
        .frame(width: 440)
        .rotation3DEffect(.degrees(30), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
        .rotationEffect(.degrees(-2))
        // Perspective makes the nearer consume edge project left; compensate so the visible unit stays centered.
        .offset(x: 45)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityLabel("Example balance bar with consume and create apps")
        .padding(.top, 6)
        .offset(y: previewFloat ? -7 : 7)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                previewFloat = true
            }
        }
    }

    private var classification: some View {
        VStack(alignment: .leading, spacing: 40) {
            heading("make it yours", subtitle: "Drag anything to the side that feels right for you.")
            ClassificationBoard(state: tracker.state, rules: $rules)
        }
    }

    private var goal: some View {
        VStack(alignment: .leading, spacing: 30) {
            heading("find your balance", subtitle: "Set the most time you want to spend consuming. You can always change it later.")
            RatioEditor(ratio: $ratio).padding(.horizontal, 2)
            Label("Your widget turns red when consume goes above \(Int((ratio * 100).rounded()))%.", systemImage: "circle.lefthalf.filled")
                .font(AppTypography.callout).foregroundStyle(BalanceStyle.secondary).padding(.top, 10)
        }.padding(.top, 10)
    }

    private var complete: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 24)
            Text("ready")
                .font(AppTypography.display(38, bold: true))
            Text("\(Int((ratio * 100).rounded()))% consume. \(100 - Int((ratio * 100).rounded()))% create.")
                .font(AppTypography.font(27, weight: .medium))
            VStack(alignment: .leading, spacing: 12) {
                Label("Your balance is in the menu bar.", systemImage: "menubar.rectangle")
                Label("Add the widget from Edit Widgets on your desktop.", systemImage: "rectangle.on.rectangle")
                Label("You can connect websites and notifications later.", systemImage: "gearshape")
            }
            .font(AppTypography.callout)
            .foregroundStyle(BalanceStyle.secondary)
            if let error = tracker.error { Text(error).font(AppTypography.caption).foregroundStyle(.red) }
            Spacer(minLength: 24)
        }
    }

    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(AppTypography.display(27, bold: true))
            Text(subtitle).font(AppTypography.font(15)).foregroundStyle(BalanceStyle.secondary)
        }
    }

}
