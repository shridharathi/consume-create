import Foundation

enum Intention: String, Codable, CaseIterable, Identifiable {
    case create, consume, ignore
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct UsageItem: Codable, Identifiable {
    var id: String
    var name: String
    var seconds: Double = 0
}

struct DailyUsage: Codable, Identifiable, Equatable {
    var day: Date
    var consumed: Double
    var created: Double
    var limit: Double

    var id: Date { day }
    var classified: Double { consumed + created }
    var ratio: Double { classified > 0 ? consumed / classified : 0 }
    var consumePercent: Int { Int((ratio * 100).rounded()) }
    var createPercent: Int { classified > 0 ? 100 - consumePercent : 0 }
    var overLimit: Bool { classified > 0 && ratio > limit }
}

struct UsageState: Codable {
    var day = Calendar.current.startOfDay(for: Date())
    var updatedAt = Date()
    var items: [String: UsageItem] = [:]
    var rules: [String: Intention] = [
        "com.todesktop.230313mzl4w4u92": .create,
        "com.microsoft.VSCode": .create,
        "com.microsoft.Word": .create,
        "com.apple.dt.Xcode": .create,
        "com.apple.Terminal": .create,
        "com.anthropic.claudefordesktop": .create,
        "com.openai.codex": .create,
        "notion.id": .create,
        "web:x.com": .consume,
        "web:twitter.com": .consume,
        "web:instagram.com": .consume,
        "web:facebook.com": .consume,
        "web:youtube.com": .consume,
        "web:reddit.com": .consume,
        "web:notion.so": .create,
        "web:claude.ai": .create
    ]
    var limit: Double = 0.5
    var paused = false
    var websites = false
    var notifications = false
    // Optional keeps existing saved snapshots decodable. New and migrated installs default to on.
    var automaticBlocking: Bool?
    // Optional keeps snapshots from versions before calendar history decodable.
    var history: [DailyUsage]?
    var lastAlert: Date?
    // Optional for backwards-compatible decoding of existing usage snapshots.
    var onboardingComplete: Bool?

    func intention(for id: String) -> Intention {
        if let rule = rules[id] { return rule }
        if id.hasPrefix("web:") {
            var parts = String(id.dropFirst(4)).split(separator: ".")
            while parts.count > 2 {
                parts.removeFirst()
                if let rule = rules["web:" + parts.joined(separator: ".")] { return rule }
            }
        }
        return .ignore
    }

    var created: Double { total(.create) }
    var consumed: Double { total(.consume) }
    var classified: Double { created + consumed }
    var ratio: Double { classified > 0 ? consumed / classified : 0 }
    var overLimit: Bool { classified > 0 && ratio > limit }
    var percent: Int { Int((ratio * 100).rounded()) }
    var blocksConsumeAutomatically: Bool { automaticBlocking ?? true }
    var createSecondsToTarget: Double {
        guard overLimit, limit > 0 else { return 0 }
        return max(0, consumed / limit - classified)
    }
    var dailyHistory: [DailyUsage] { history ?? [] }

    func summary(for date: Date, calendar: Calendar = .current) -> DailyUsage? {
        let start = calendar.startOfDay(for: date)
        if calendar.isDate(start, inSameDayAs: day) {
            guard classified > 0 else { return nil }
            return DailyUsage(day: day, consumed: consumed, created: created, limit: limit)
        }
        return dailyHistory.first { calendar.isDate($0.day, inSameDayAs: start) }
    }

    func total(_ intention: Intention) -> Double {
        items.values.filter { self.intention(for: $0.id) == intention }.reduce(0) { $0 + $1.seconds }
    }

    mutating func rollDay(at date: Date) {
        let start = Calendar.current.startOfDay(for: date)
        if start != day {
            archiveCurrentDay()
            day = start
            items = [:]
            lastAlert = nil
        }
    }

    private mutating func archiveCurrentDay() {
        guard classified > 0 else { return }
        var entries = dailyHistory.filter { !Calendar.current.isDate($0.day, inSameDayAs: day) }
        entries.append(DailyUsage(day: day, consumed: consumed, created: created, limit: limit))
        history = Array(entries.sorted { $0.day < $1.day }.suffix(730))
    }

    mutating func record(id: String, name: String, from start: Date, to end: Date) {
        rollDay(at: end)
        let duration = end.timeIntervalSince(max(start, day))
        guard duration > 0, duration <= 30, !paused else { return }
        var item = items[id] ?? UsageItem(id: id, name: name)
        item.seconds += duration
        items[id] = item
        updatedAt = end
    }

    static func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        if minutes == 0 { return seconds > 0 ? "<1m" : "0m" }
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

enum SharedStore {
    static var location: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "ConsumeCreateGroup") as? String,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        return container.appendingPathComponent("balance.json")
    }
    static func read() throws -> UsageState {
        guard let url = location else { throw CocoaError(.fileReadNoPermission) }
        guard FileManager.default.fileExists(atPath: url.path) else { return UsageState() }
        var value = try JSONDecoder().decode(UsageState.self, from: Data(contentsOf: url))
        value.rollDay(at: Date())
        return value
    }
    static func write(_ value: UsageState) throws {
        guard let url = location else { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
