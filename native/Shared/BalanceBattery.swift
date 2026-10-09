import SwiftUI
import AppKit

enum BalanceStyle {
    // Matte, near-black surfaces keep the interface quiet and let the balance signal lead.
    static let ink = Color(red: 0.005, green: 0.005, blue: 0.005)
    static let canvas = Color(red: 0.008, green: 0.008, blue: 0.008)
    static let surface = Color(red: 0.035, green: 0.035, blue: 0.035)
    static let surfaceRaised = Color(red: 0.075, green: 0.075, blue: 0.075)
    static let text = Color.white.opacity(0.97)
    static let secondary = Color.white.opacity(0.50)
    static let accent = Color(red: 1, green: 0.23, blue: 0.06)
    static let consume = accent
    static let create = Color.white.opacity(0.92)
    static let alert = Color(red: 1, green: 0.20, blue: 0.12)
    static func consumeFill(_ state: UsageState) -> Color { state.overLimit ? alert : accent }
}

struct BalanceBattery: View {
    let state: UsageState
    var square = false
    var edgeToEdge = false
    var prominent = false
    var showsStatus = true
    var target: Double? = nil
    var onTargetChange: ((Double) -> Void)? = nil

    @State private var hoveringTarget = false
    @State private var draggingTarget = false
    @State private var dragStartTarget: Double?
    @State private var temporaryTarget: Double?
    @State private var targetCursorActive = false

    private var consumeText: String { state.classified > 0 ? "\(state.percent)%" : "—" }
    private var createText: String { state.classified > 0 ? "\(100 - state.percent)%" : "—" }

    var body: some View {
        VStack(alignment: .leading, spacing: square ? 8 : (prominent ? 12 : 8)) {
            if showsStatus {
                Text(statusHeadline)
                    .font(AppTypography.font(prominent ? 16 : (square ? 10 : 12), weight: .medium))
                    .foregroundStyle(state.overLimit ? BalanceStyle.alert : BalanceStyle.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if square {
                squareMetrics
            } else {
                wideMetrics
            }
            VStack(spacing: 0) {
                if let displayedTarget {
                    targetReadout(target: displayedTarget)
                        .frame(height: 54)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: square ? 9 : 16)
                            .fill(Color.white.opacity(0.84))
                        RoundedRectangle(cornerRadius: square ? 9 : 16)
                            .fill(BalanceStyle.consumeFill(state))
                            .frame(width: max(0, proxy.size.width * state.ratio))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: square ? 9 : 16))
                    .overlay(alignment: .leading) {
                        if let displayedTarget {
                            targetHandle(target: displayedTarget, width: proxy.size.width, height: proxy.size.height)
                                .allowsHitTesting(false)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: square ? 9 : 16))
                    .onContinuousHover { phase in
                        guard let displayedTarget else { return }
                        switch phase {
                        case .active(let location):
                            setTargetHover(abs(location.x - proxy.size.width * displayedTarget) < 48)
                        case .ended:
                            setTargetHover(false)
                        }
                    }
                    .highPriorityGesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let displayedTarget else { return }
                            if dragStartTarget == nil {
                                guard abs(value.startLocation.x - proxy.size.width * displayedTarget) < 48 else { return }
                                dragStartTarget = displayedTarget
                            }
                            draggingTarget = true
                            updateTargetCursor(true)
                            temporaryTarget = Self.clampedTarget((dragStartTarget ?? displayedTarget) + Double(value.translation.width / proxy.size.width))
                        }
                        .onEnded { _ in
                            guard dragStartTarget != nil else { return }
                            let finalTarget = temporaryTarget ?? displayedTarget ?? 0.5
                            dragStartTarget = nil
                            temporaryTarget = nil
                            draggingTarget = false
                            updateTargetCursor(hoveringTarget)
                            onTargetChange?(finalTarget)
                        })
                }
                .frame(height: square ? 44 : (prominent ? 72 : 45))
            }
            .frame(height: (target == nil ? 0 : 54) + (square ? 44 : (prominent ? 72 : 45)))
        }
        .padding(square ? 14 : (edgeToEdge ? 16 : 12))
        .foregroundStyle(BalanceStyle.text)
        .background(edgeToEdge ? Color.clear : BalanceStyle.canvas)
        .clipShape(RoundedRectangle(cornerRadius: edgeToEdge ? 0 : 30))
        .onDisappear { releaseTargetCursor() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.classified > 0 ? "Today: \(state.percent) percent consume, \(100 - state.percent) percent create. \(statusHeadline)" : "No activity yet. \(statusHeadline)")
    }

    private var displayedTarget: Double? {
        guard let target else { return nil }
        return temporaryTarget ?? Self.clampedTarget(target)
    }

    @ViewBuilder
    private func targetHandle(target: Double, width: CGFloat, height: CGFloat) -> some View {
        let handleX = width * target
        Rectangle()
            .fill(BalanceStyle.ink.opacity(0.78))
            .frame(width: hoveringTarget || draggingTarget ? 4 : 3, height: height)
        .frame(width: 80, height: height)
        .offset(x: handleX - 40)
    }

    private func targetReadout(target: Double) -> some View {
        GeometryReader { proxy in
            let targetX = min(max(proxy.size.width * target, 34), proxy.size.width - 34)
            VStack(spacing: 4) {
                Text("\(Int((target * 100).rounded()))%")
                    .font(AppTypography.font(15, weight: .semibold))
                Text("target")
                    .font(AppTypography.font(14, weight: .semibold))
            }
            .fixedSize()
            .position(x: targetX, y: 24)
            .animation(.easeOut(duration: 0.12), value: hoveringTarget || draggingTarget)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location): setTargetHover(abs(location.x - targetX) < 48)
                case .ended: setTargetHover(false)
                }
            }
        }
    }

    private func setTargetHover(_ hovering: Bool) {
        hoveringTarget = hovering
        updateTargetCursor(hovering || draggingTarget)
    }

    private func updateTargetCursor(_ active: Bool) {
        guard active != targetCursorActive else { return }
        if active {
            NSCursor.resizeLeftRight.push()
        } else {
            NSCursor.pop()
        }
        targetCursorActive = active
    }

    private func releaseTargetCursor() {
        guard targetCursorActive else { return }
        NSCursor.pop()
        targetCursorActive = false
    }

    private static func clampedTarget(_ value: Double) -> Double {
        min(0.5, max(0.1, (value * 20).rounded() / 20))
    }

    private var squareMetrics: some View {
        HStack(alignment: .bottom, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text("consume")
                    .font(AppTypography.font(9, weight: .semibold))
                    .tracking(0.45)
                    .foregroundStyle(BalanceStyle.consumeFill(state))
                    .lineLimit(1).fixedSize()
                Text(consumeText).font(AppTypography.font(24, weight: .medium))
            }
            Spacer(minLength: 2)
            VStack(alignment: .trailing, spacing: 1) {
                Text("create").font(AppTypography.font(9, weight: .semibold)).tracking(0.45).foregroundStyle(BalanceStyle.secondary)
                Text(createText).font(AppTypography.font(24, weight: .medium))
            }
        }
    }

    private var wideMetrics: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: -1) {
                Text("consume")
                    .font(AppTypography.font(prominent ? 16 : 13, weight: .regular))
                    .foregroundStyle(BalanceStyle.secondary)
                Text(consumeText)
                    .font(AppTypography.font(prominent ? 52 : 42, weight: .medium))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: -1) {
                Text("create")
                    .font(AppTypography.font(prominent ? 16 : 13, weight: .regular))
                    .foregroundStyle(BalanceStyle.secondary)
                Text(createText)
                    .font(AppTypography.font(prominent ? 52 : 42, weight: .medium))
            }
        }
        .padding(.top, prominent ? 18 : 0)
    }

    private var status: String {
        if state.paused { return "Tracking paused" }
        if state.classified == 0 { return "Ready to begin" }
        return state.overLimit ? "Above consume goal" : "Within goal"
    }

    static func headline(for state: UsageState) -> String {
        state.overLimit ? "You're consuming too much." : "Nice. You're creating today."
    }

    private var statusHeadline: String { Self.headline(for: state) }
}
