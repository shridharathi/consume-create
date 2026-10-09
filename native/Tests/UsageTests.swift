import Foundation

@main struct UsageTests {
    static func main() {
        var state = UsageState()
        let now = Date()
        state.rules = ["writer": .create, "feed": .consume, "web:example.com": .create]
        state.record(id: "writer", name: "Writer", from: now.addingTimeInterval(-20), to: now)
        state.record(id: "feed", name: "Feed", from: now.addingTimeInterval(-20), to: now)
        assert(state.ratio == 0.5 && !state.overLimit)
        state.record(id: "feed", name: "Feed", from: now.addingTimeInterval(-10), to: now)
        assert(state.overLimit && state.percent == 60)
        assert(state.blocksConsumeAutomatically)
        assert(abs(state.createSecondsToTarget - 10) < 0.001)
        state.record(id: "unknown", name: "Unknown", from: now.addingTimeInterval(-20), to: now)
        assert(state.classified == 50)
        state.paused = true
        state.record(id: "feed", name: "Feed", from: now.addingTimeInterval(-10), to: now)
        assert(state.consumed == 30)
        state.paused = false
        state.record(id: "feed", name: "Feed", from: now.addingTimeInterval(-3600), to: now)
        assert(state.consumed == 30, "Sleep gaps must not be counted")
        assert(state.intention(for: "web:docs.example.com") == .create)
        assert(state.intention(for: "web:notexample.com") == .ignore)
        state.rules["feed"] = .create
        assert(state.ratio == 0, "Reclassification applies to today's totals")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: state.day)!
        state.record(id: "writer", name: "Writer", from: tomorrow.addingTimeInterval(-5), to: tomorrow.addingTimeInterval(5))
        assert(state.created == 5 && state.items.count == 1, "Midnight splits intervals")
        assert(state.dailyHistory.count == 1 && state.dailyHistory[0].classified == 50, "Day rollover archives the prior ratio")
        assert(state.rules["writer"] == .create)
        let roundTrip = try! JSONDecoder().decode(UsageState.self, from: JSONEncoder().encode(state))
        assert(roundTrip.created == 5 && roundTrip.limit == 0.5)
        var legacy = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        legacy.removeValue(forKey: "onboardingComplete")
        legacy.removeValue(forKey: "automaticBlocking")
        legacy.removeValue(forKey: "history")
        let migrated = try! JSONDecoder().decode(UsageState.self, from: JSONSerialization.data(withJSONObject: legacy))
        assert(migrated.onboardingComplete == nil && migrated.blocksConsumeAutomatically && migrated.dailyHistory.isEmpty && migrated.created == 5 && migrated.rules == state.rules)
        state.onboardingComplete = true
        let finished = try! JSONDecoder().decode(UsageState.self, from: JSONEncoder().encode(state))
        assert(finished.onboardingComplete == true)
        print("Usage tests passed: ratios, limits, blocking, calendar history, ignore, pause, sleep gaps, domain matching, reclassification, midnight, persistence")
    }
}
