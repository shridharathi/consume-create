import SwiftUI

struct CalendarSheet: View {
    let tracker: ActivityTracker
    @Environment(\.dismiss) private var dismiss
    @State private var month: Date
    @State private var selectedDay: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    init(tracker: ActivityTracker) {
        self.tracker = tracker
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        _month = State(initialValue: calendar.dateInterval(of: .month, for: today)?.start ?? today)
        _selectedDay = State(initialValue: today)
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 66)
                    }
                }
            }
            selectionDetails
            Spacer(minLength: 0)
        }
        .font(AppTypography.body)
        .foregroundStyle(BalanceStyle.text)
        .padding(28)
        .frame(width: 680, height: 720)
        .background(BalanceStyle.canvas)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your balance")
                    .font(AppTypography.font(30, weight: .semibold))
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(AppTypography.font(15, weight: .medium))
                    .foregroundStyle(BalanceStyle.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                monthButton("chevron.left", offset: -1, disabled: false)
                monthButton("chevron.right", offset: 1, disabled: !canMoveForward)
                Button("Done") { dismiss() }
                    .buttonStyle(PrimaryAction())
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(AppTypography.font(11, weight: .semibold))
                    .foregroundStyle(BalanceStyle.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let summary = tracker.state.summary(for: date)
        let selected = calendar.isDate(date, inSameDayAs: selectedDay)
        let today = calendar.isDateInToday(date)
        return Button { selectedDay = date } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("\(calendar.component(.day, from: date))")
                        .font(AppTypography.font(12, weight: .semibold))
                    Spacer()
                    if today {
                        Circle().fill(BalanceStyle.accent).frame(width: 5, height: 5)
                    }
                }
                if let summary {
                    Text("\(summary.consumePercent)%")
                        .font(AppTypography.font(18, weight: .semibold))
                    ratioBar(summary)
                } else {
                    Text("—")
                        .font(AppTypography.font(18, weight: .medium))
                        .foregroundStyle(BalanceStyle.secondary.opacity(0.45))
                    Capsule().fill(.white.opacity(0.06)).frame(height: 5)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
            .background(selected ? BalanceStyle.surfaceRaised : BalanceStyle.surface, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? BalanceStyle.accent : .white.opacity(0.05), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel(date, summary: summary))
    }

    private func ratioBar(_ summary: DailyUsage) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(BalanceStyle.create)
                Capsule().fill(summary.overLimit ? BalanceStyle.alert : BalanceStyle.accent)
                    .frame(width: proxy.size.width * summary.ratio)
            }
        }
        .frame(height: 5)
    }

    @ViewBuilder private var selectionDetails: some View {
        let summary = tracker.state.summary(for: selectedDay)
        VStack(alignment: .leading, spacing: 13) {
            Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(AppTypography.font(15, weight: .semibold))
            if let summary {
                HStack(spacing: 12) {
                    detailMetric("consume", value: "\(summary.consumePercent)%", time: UsageState.duration(summary.consumed), color: summary.overLimit ? BalanceStyle.alert : BalanceStyle.accent)
                    detailMetric("create", value: "\(summary.createPercent)%", time: UsageState.duration(summary.created), color: .white)
                }
            } else {
                Text("No classified time for this day.")
                    .font(AppTypography.font(14))
                    .foregroundStyle(BalanceStyle.secondary)
                    .padding(.vertical, 16)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BalanceStyle.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.06)))
    }

    private func detailMetric(_ title: String, value: String, time: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTypography.font(12, weight: .medium)).foregroundStyle(BalanceStyle.secondary)
                Text(value).font(AppTypography.font(24, weight: .semibold))
            }
            Spacer()
            Text(time).font(AppTypography.font(13, weight: .semibold)).foregroundStyle(BalanceStyle.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(BalanceStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
    }

    private var monthDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let days = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var values = Array<Date?>(repeating: nil, count: leading)
        values += days.compactMap { day in calendar.date(byAdding: .day, value: day - 1, to: interval.start) }
        while values.count % 7 != 0 { values.append(nil) }
        return values
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private var canMoveForward: Bool {
        guard let currentMonth = calendar.dateInterval(of: .month, for: Date())?.start else { return false }
        return month < currentMonth
    }

    private func monthButton(_ symbol: String, offset: Int, disabled: Bool) -> some View {
        Button {
            if let next = calendar.date(byAdding: .month, value: offset, to: month) {
                month = next
                selectedDay = next
            }
        } label: {
            Image(systemName: symbol)
                .frame(width: 31, height: 31)
                .background(BalanceStyle.surfaceRaised, in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? BalanceStyle.secondary.opacity(0.35) : BalanceStyle.text)
        .disabled(disabled)
    }

    private func dayAccessibilityLabel(_ date: Date, summary: DailyUsage?) -> String {
        let day = date.formatted(.dateTime.month(.wide).day())
        guard let summary else { return "\(day), no classified time" }
        return "\(day), \(summary.consumePercent) percent consume, \(summary.createPercent) percent create"
    }
}
