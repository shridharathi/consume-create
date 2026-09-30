import SwiftUI
import AppKit

@main struct RenderCalendar {
    @MainActor static func main() throws {
        let tracker = ActivityTracker()
        var state = UsageState()
        state.onboardingComplete = true
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        state.day = today
        state.items = [
            "consume": UsageItem(id: "consume", name: "Consume", seconds: 3600),
            "create": UsageItem(id: "create", name: "Create", seconds: 5400)
        ]
        state.rules = ["consume": .consume, "create": .create]
        state.history = (1...16).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let consumed = Double((offset % 5 + 1) * 900)
            let created = Double((offset % 4 + 1) * 1200)
            return DailyUsage(day: day, consumed: consumed, created: created, limit: 0.5)
        }
        tracker.state = state

        let renderer = ImageRenderer(content: CalendarSheet(tracker: tracker))
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            fatalError("Could not render calendar")
        }
        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
