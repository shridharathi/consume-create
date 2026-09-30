import SwiftUI
import WidgetKit

struct BalanceEntry: TimelineEntry {
    let date: Date
    let state: UsageState
    var unavailable = false
}

struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry { BalanceEntry(date: Date(), state: UsageState()) }
    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        completion(Timeline(entries: [entry()], policy: .after(min(now.addingTimeInterval(900), midnight))))
    }
    private func entry() -> BalanceEntry {
        do { return BalanceEntry(date: Date(), state: try SharedStore.read()) }
        catch { return BalanceEntry(date: Date(), state: UsageState(), unavailable: true) }
    }
}

struct BalanceWidgetView: View {
    let entry: BalanceEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        BalanceBattery(state: entry.state, square: family == .systemSmall, edgeToEdge: true)
        .overlay {
            if entry.unavailable {
                Text("Open consume:create to get started")
                    .font(AppTypography.caption).padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BalanceStyle.canvas).foregroundStyle(BalanceStyle.text)
            }
        }
        .containerBackground(for: .widget) { BalanceStyle.canvas }
        .widgetURL(URL(string: "consume-create://overview"))
    }
}

@main
struct ConsumeCreateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ConsumeCreateWidget", provider: BalanceProvider()) { BalanceWidgetView(entry: $0) }
            .configurationDisplayName("consume:create")
            .description("Less scrolling. More making. Your daily balance at a glance.")
            .supportedFamilies([.systemSmall, .systemMedium])
            .contentMarginsDisabled()
    }
}
