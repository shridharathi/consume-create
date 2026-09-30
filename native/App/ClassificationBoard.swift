import SwiftUI
import UniformTypeIdentifiers

struct ClassificationBoard: View {
    let state: UsageState
    @Binding var rules: [String: Intention]
    @State private var targeted: Intention?
    @State private var draggedID: String?
    @State private var dragLocation = CGPoint.zero
    @State private var dropFrames: [Intention: CGRect] = [:]
    @State private var websiteColumn: Intention?
    @State private var website = ""
    @State private var websiteError: String?
    @State private var showIgnored = false
    private var items: [IntentionItem] { IntentionItem.all(in: state, rules: rules) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 18) {
                column(.consume, color: BalanceStyle.consume)
                column(.create, color: BalanceStyle.create)
            }
            DisclosureGroup("Not counted (\(items.filter { category($0) == .ignore }.count))", isExpanded: $showIgnored) {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(items.filter { category($0) == .ignore }) { item in
                            HStack {
                                AppBadge(item: item)
                                Text(item.name).font(AppTypography.caption).lineLimit(1)
                                Spacer()
                                Menu {
                                    Button("Move to consume") { move(item.id, to: .consume) }
                                    Button("Move to create") { move(item.id, to: .create) }
                                } label: { Image(systemName: "plus.circle") }.menuStyle(.borderlessButton).frame(width: 24)
                            }.padding(7).background(BalanceStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
                                .simultaneousGesture(cardDrag(item))
                        }
                    }
                }.frame(maxHeight: 140)
            }.font(AppTypography.caption).foregroundStyle(BalanceStyle.secondary)
                .padding(10).background(BalanceStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                .background(dropFrame(.ignore))
        }
        .coordinateSpace(name: "classification-board")
        .onPreferenceChange(DropFrameKey.self) { dropFrames = $0 }
        .overlay(alignment: .topLeading) {
            if let id = draggedID, let item = items.first(where: { $0.id == id }) {
                HStack(spacing: 10) {
                    AppBadge(item: item)
                    Text(item.name).font(AppTypography.font(13, weight: .medium))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.left.and.right").font(.caption)
                }
                .padding(12).frame(width: 230)
                .background(BalanceStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.17), radius: 15, y: 7)
                .rotationEffect(.degrees(-3))
                .position(dragLocation).allowsHitTesting(false)
            }
        }
        .sheet(item: $websiteColumn) { intention in
            VStack(alignment: .leading, spacing: 18) {
                Text("Add a website").font(AppTypography.title2)
                TextField("e.g. youtube.com", text: $website).textFieldStyle(.roundedBorder)
                    .onSubmit { addWebsite(to: intention) }
                if let websiteError { Text(websiteError).font(AppTypography.caption).foregroundStyle(.red) }
                HStack {
                    Button("Cancel") { websiteColumn = nil }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Add to \(intention.rawValue)") { addWebsite(to: intention) }.buttonStyle(PrimaryAction())
                }
            }.font(AppTypography.body).foregroundStyle(BalanceStyle.text).padding(28).frame(width: 380).background(BalanceStyle.canvas)
        }
    }

    private func category(_ item: IntentionItem) -> Intention { rules[item.id] ?? .ignore }

    private func column(_ intention: Intention, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(intention.rawValue).font(AppTypography.font(26, weight: .semibold))
                Spacer()
                Text("\(items.filter { category($0) == intention }.count)")
                    .font(AppTypography.font(13, weight: .medium))
                    .foregroundStyle(BalanceStyle.secondary)
            }.padding(.horizontal, 4)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items.filter { category($0) == intention }) { item in card(item, in: intention) }
                    if !items.contains(where: { category($0) == intention }) {
                        Text("Drop something here").foregroundStyle(BalanceStyle.secondary).frame(maxWidth: .infinity, minHeight: 130)
                    }
                }.padding(2)
            }.frame(height: 300)
            Menu {
                Button("Add an app…") { addApplications(to: intention) }
                Button("Add a website…") { website = ""; websiteError = nil; websiteColumn = intention }
            } label: { Label("Add your own", systemImage: "plus").font(AppTypography.font(13, weight: .medium)) }
                .menuStyle(.borderlessButton).fixedSize()
                .padding(.horizontal, 5).padding(.bottom, 2)
        }
        .padding(15).frame(maxWidth: .infinity)
        .background(BalanceStyle.surface, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(targeted == intention ? color.opacity(0.8) : .white.opacity(0.07), lineWidth: targeted == intention ? 2 : 1))
        .background(dropFrame(intention))
        .animation(.snappy, value: targeted)
    }

    private func card(_ item: IntentionItem, in intention: Intention) -> some View {
        HStack(spacing: 10) {
            AppBadge(item: item)
            Text(item.name).font(AppTypography.font(13, weight: .medium)).lineLimit(1)
            Spacer(minLength: 0)
            Button { move(item.id, to: intention == .consume ? .create : .consume) } label: {
                Image(systemName: intention == .consume ? "arrow.right" : "arrow.left")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(BalanceStyle.secondary)
                    .padding(6).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .help("Move \(item.name) to \(intention == .consume ? "create" : "consume")")
                .accessibilityLabel("Move \(item.name) to \(intention == .consume ? "create" : "consume")")
        }
        .padding(10).background(BalanceStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 13))
        .contentShape(RoundedRectangle(cornerRadius: 13))
        .opacity(draggedID == item.id ? 0.35 : 1)
        .simultaneousGesture(cardDrag(item))
        .contextMenu {
            Button("Move to \(intention == .consume ? "create" : "consume")") { move(item.id, to: intention == .consume ? .create : .consume) }
            Button("Don’t count this") { move(item.id, to: .ignore) }
        }
    }

    private func move(_ id: String, to intention: Intention) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        withAnimation(.snappy) {
            rules[id] = intention
        }
    }

    private func cardDrag(_ item: IntentionItem) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("classification-board"))
            .onChanged { value in
                draggedID = item.id
                dragLocation = value.location
                targeted = dropFrames.first(where: { $0.value.contains(value.location) })?.key
            }
            .onEnded { value in
                if let destination = dropFrames.first(where: { $0.value.contains(value.location) })?.key {
                    move(item.id, to: destination)
                }
                draggedID = nil
                targeted = nil
            }
    }

    private func dropFrame(_ intention: Intention) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: DropFrameKey.self, value: [intention: proxy.frame(in: .named("classification-board"))])
        }
    }

    private func addApplications(to intention: Intention) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let id = Bundle(url: url)?.bundleIdentifier { rules[id] = intention }
            }
        }
    }

    private func addWebsite(to intention: Intention) {
        let input = website.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let url = URL(string: input.contains("://") ? input : "https://" + input),
              let host = url.host, host.contains("."), !host.contains(" "), ["https", "http"].contains(url.scheme ?? "") else {
            websiteError = "Try a domain like youtube.com."; return
        }
        rules["web:" + host] = intention
        websiteColumn = nil
    }
}

private struct DropFrameKey: PreferenceKey {
    static var defaultValue: [Intention: CGRect] = [:]
    static func reduce(value: inout [Intention: CGRect], nextValue: () -> [Intention: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
