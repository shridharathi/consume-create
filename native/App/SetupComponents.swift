import SwiftUI
import AppKit

struct IntentionItem: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let suggested: Intention
    var website: Bool { id.hasPrefix("web:") }

    var brandIconURL: URL? {
        let domain: String?
        switch id {
        case "com.openai.codex": domain = "openai.com"
        case "com.todesktop.230313mzl4w4u92": domain = "cursor.com"
        case "notion.id": domain = "notion.so"
        case "com.microsoft.Word": domain = "microsoft.com"
        default: domain = website ? String(id.dropFirst(4)) : nil
        }
        guard let domain else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=128")
    }

    static let suggestions: [Self] = [
        .init(id: "web:instagram.com", name: "Instagram", symbol: "camera", suggested: .consume),
        .init(id: "web:youtube.com", name: "YouTube", symbol: "play.rectangle", suggested: .consume),
        .init(id: "web:x.com", name: "X / Twitter", symbol: "bubble.left", suggested: .consume),
        .init(id: "web:reddit.com", name: "Reddit", symbol: "bubble.left.and.bubble.right", suggested: .consume),
        .init(id: "web:facebook.com", name: "Facebook", symbol: "person.2", suggested: .consume),
        .init(id: "web:tiktok.com", name: "TikTok", symbol: "music.note", suggested: .consume),
        .init(id: "com.openai.codex", name: "Codex", symbol: "terminal", suggested: .create),
        .init(id: "com.todesktop.230313mzl4w4u92", name: "Cursor", symbol: "cursorarrow", suggested: .create),
        .init(id: "com.apple.Terminal", name: "Terminal / Claude Code", symbol: "terminal", suggested: .create),
        .init(id: "notion.id", name: "Notion", symbol: "doc.text", suggested: .create),
        .init(id: "com.microsoft.Word", name: "Microsoft Word", symbol: "doc.richtext", suggested: .create),
        .init(id: "web:claude.ai", name: "Claude", symbol: "sparkle", suggested: .create)
    ]

    static func all(in state: UsageState, rules: [String: Intention]) -> [Self] {
        var result = suggestions
        let known = Set(result.map(\.id))
        for id in Set(rules.keys).union(state.items.keys).subtracting(known).sorted() {
            let name = state.items[id]?.name
                ?? (id.hasPrefix("web:") ? String(id.dropFirst(4)) : NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent)
                ?? id.split(separator: ".").last.map(String.init) ?? id
            result.append(.init(id: id, name: name, symbol: id.hasPrefix("web:") ? "globe" : "app", suggested: .ignore))
        }
        return result
    }

    static func startingRules(_ existing: [String: Intention]) -> [String: Intention] {
        var result = existing
        for item in suggestions where result[item.id] == nil { result[item.id] = item.suggested }
        return result
    }
}

struct AppBadge: View {
    let item: IntentionItem
    var body: some View {
        Group {
            if !item.website, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.id) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit()
            } else if let url = item.brandIconURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().padding(2)
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }.frame(width: 32, height: 32).foregroundStyle(BalanceStyle.text)
    }

    private var fallback: some View {
        Image(systemName: item.symbol).font(.system(size: 16, weight: .medium))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BalanceStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 9))
    }
}

struct PrimaryAction: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(AppTypography.font(15, weight: .semibold))
            .padding(.horizontal, 24).padding(.vertical, 13)
            .foregroundStyle(BalanceStyle.ink)
            .background(BalanceStyle.accent.opacity(configuration.isPressed ? 0.75 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct RatioEditor: View {
    @Binding var ratio: Double
    @State private var dragging = false
    @State private var hoveringTarget = false
    @State private var targetCursorActive = false
    private var consumePercent: Int { Int((ratio * 100).rounded()) }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                ratioLabel("consume", consumePercent, alignment: .leading)
                Spacer()
                ratioLabel("create", 100 - consumePercent, alignment: .trailing)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Color.white.opacity(0.9)
                    Rectangle().fill(BalanceStyle.accent).frame(width: geometry.size.width * ratio)
                    Rectangle().fill(BalanceStyle.ink.opacity(0.8)).frame(width: 3, height: 180)
                        .offset(x: geometry.size.width * ratio - 1.5)
                    Capsule().fill(.white)
                        .frame(width: 18, height: hoveringTarget || dragging ? 68 : 44)
                        .shadow(color: .black.opacity(0.2), radius: dragging ? 12 : 5, y: 3)
                        .scaleEffect(dragging ? 1.08 : 1)
                        .offset(x: geometry.size.width * ratio - 9)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    dragging = true
                    ratio = Self.snapped(value.location.x / geometry.size.width)
                }.onEnded { _ in dragging = false })
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        let targetX = geometry.size.width * ratio
                        setTargetHover(abs(location.x - targetX) < 48)
                    case .ended:
                        setTargetHover(false)
                    }
                }
                .help("Drag the target line to set your consume limit")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Consume to create goal")
                .accessibilityValue("\(consumePercent) percent consume, \(100 - consumePercent) percent create")
                .accessibilityAdjustableAction { direction in
                    ratio = Self.snapped(ratio + (direction == .increment ? 0.05 : -0.05))
                }
            }.frame(height: 180)
            HStack(spacing: 10) {
                ForEach([10, 20, 30, 40, 50], id: \.self) { consume in
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            ratio = Double(consume) / 100
                        }
                    } label: {
                        Text("\(consume):\(100 - consume)")
                            .font(AppTypography.font(13, weight: .medium))
                            .foregroundStyle(consumePercent == consume ? BalanceStyle.text : BalanceStyle.secondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(
                                consumePercent == consume ? Color.white.opacity(0.12) : Color.clear,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(consume) percent consume, \(100 - consume) percent create")
                }
            }
            .frame(maxWidth: .infinity)
            Text("Hover the target line, then drag it.").foregroundStyle(BalanceStyle.secondary)
        }
        .onAppear { ratio = Self.snapped(ratio) }
        .onDisappear { releaseTargetCursor() }
    }

    static func snapped(_ value: Double) -> Double {
        min(0.5, max(0.1, (value * 20).rounded() / 20))
    }

    private func ratioLabel(_ title: String, _ value: Int, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text("\(value)%").font(AppTypography.font(50, weight: .semibold))
            Text(title).font(AppTypography.font(16, weight: .medium)).tracking(0.1).foregroundStyle(BalanceStyle.secondary)
        }
    }

    private func setTargetHover(_ hovering: Bool) {
        hoveringTarget = hovering
        guard hovering != targetCursorActive else { return }
        if hovering {
            NSCursor.resizeLeftRight.push()
        } else {
            NSCursor.pop()
        }
        targetCursorActive = hovering
    }

    private func releaseTargetCursor() {
        guard targetCursorActive else { return }
        NSCursor.pop()
        targetCursorActive = false
    }

}
