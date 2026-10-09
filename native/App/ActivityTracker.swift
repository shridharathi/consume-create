import AppKit
import Observation
import UserNotifications
import WidgetKit
import CoreGraphics

struct BlockedActivity: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let minutesToUnlock: Int
}

@MainActor @Observable
final class ActivityTracker {
    var state = UsageState()
    var error: String?
    var browserStatus = "Website tracking is off."
    var blockedActivity: BlockedActivity?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var lastTick = Date()
    private var active: (id: String, name: String)?
    private var sleeping = false
    private var locked = false
    private var lastReload = Date.distantPast
    private var lastSave = Date.distantPast
    private var browserBusy = false
    private var domain: String?
    private var browserGeneration = 0
    private var domainReadAt = Date.distantPast
    private var browserChecked = Date.distantPast
    private var canSave = true
    private var lastEnforcedID: String?
    private var lastEnforcedAt = Date.distantPast

    private let browserIDs = ["com.apple.Safari", "com.google.Chrome"]

    init() {
        do { state = try SharedStore.read() }
        catch { self.error = "Could not load saved usage: \(error.localizedDescription)"; canSave = false }
        refreshActive()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
                self?.domain = nil
                self?.browserGeneration += 1
                self?.refreshActive()
            }
        })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.tick(); self?.sleeping = true; self?.save(forceReload: true) }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.sleeping = false; self?.lastTick = Date(); self?.refreshActive() }
            })
        }
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick(); self?.locked = true; self?.save(forceReload: true) }
        })
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.locked = false; self?.lastTick = Date(); self?.refreshActive() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick(); self?.save(forceReload: true) }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        save(forceReload: true)
    }

    func tick() {
        let now = Date()
        let wasOver = state.overLimit
        // kCGAnyInputEventType, not .null (which measures only synthetic null events).
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        state.rollDay(at: now)
        if now.timeIntervalSince(domainReadAt) > 15 { domain = nil }
        if !sleeping, !locked, idle < 60, !state.paused, let active {
            let id = domain.map { "web:" + $0 } ?? active.id
            state.record(id: id, name: domain ?? active.name, from: lastTick, to: now)
        }
        lastTick = now
        refreshActive()
        enforceIfNeeded(at: now)
        if state.websites, !sleeping, !locked, !state.paused, now.timeIntervalSince(browserChecked) >= 5 { readBrowser() }
        if state.overLimit, state.classified >= 300, state.notifications,
           state.lastAlert == nil || (!wasOver && now.timeIntervalSince(state.lastAlert!) >= 1800) {
            sendNudge()
        }
        if now.timeIntervalSince(lastSave) >= 10 || wasOver != state.overLimit { save(forceReload: wasOver != state.overLimit) }
    }

    private func refreshActive() {
        guard let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier,
              id != Bundle.main.bundleIdentifier, id != "com.apple.loginwindow" else { active = nil; domain = nil; return }
        if active?.id != id { domain = nil; browserChecked = .distantPast; browserGeneration += 1 }
        active = (id, app.localizedName ?? id)
    }

    func setRule(_ id: String, intention: Intention) { state.rules[id] = intention; save(forceReload: true) }
    func setLimit(_ limit: Double) { state.limit = limit; save(forceReload: true) }
    func setAutomaticBlocking(_ enabled: Bool) {
        state.automaticBlocking = enabled
        if !enabled { blockedActivity = nil }
        save(forceReload: true)
    }
    func dismissBlockNotice() { blockedActivity = nil }
    func togglePause() { tick(); state.paused.toggle(); lastTick = Date(); save(forceReload: true) }
    func setWebsites(_ enabled: Bool) {
        state.websites = enabled; domain = nil; browserGeneration += 1
        browserStatus = enabled ? "Switch to Safari or Chrome and approve Automation access when asked." : "Website tracking is off."
        save(forceReload: true)
    }
    func setNotifications(_ enabled: Bool) {
        if !enabled { state.notifications = false; save(); return }
        Task {
            do {
                state.notifications = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                if !state.notifications { error = "Enable notifications in System Settings → Notifications → consume:create." }
                save()
            } catch { self.error = error.localizedDescription }
        }
    }
    func save(forceReload: Bool = false) {
        guard canSave else { return }
        do {
            try SharedStore.write(state)
            lastSave = Date()
            if forceReload || Date().timeIntervalSince(lastReload) >= 900 {
                WidgetCenter.shared.reloadTimelines(ofKind: "ConsumeCreateWidget")
                lastReload = Date()
            }
        } catch { self.error = "Could not save usage: \(error.localizedDescription)" }
    }

    private func sendNudge() {
        state.lastAlert = Date()
        save()
        let content = UNMutableNotificationContent()
        content.title = "A little room for making"
        content.body = "Consumption is \(state.percent)% of your classified time, above your \(Int(state.limit * 100))% limit."
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "balance-limit", content: content, trigger: nil))
    }

    private func readBrowser() {
        guard !browserBusy, let id = active?.id, browserIDs.contains(id) else { return }
        browserBusy = true; browserChecked = Date()
        let generation = browserGeneration
        // Only constant, known browser identifiers are interpolated into AppleScript.
        let query = id == "com.apple.Safari" ? "URL of current tab of front window" : "URL of active tab of front window"
        let script = "tell application id \"\(id)\"\nif (count of windows) is 0 then return \"\"\nreturn \(query)\nend tell"
        Task {
            let result: (String?, String?) = await Task.detached {
                var failure: NSDictionary?
                let value = NSAppleScript(source: script)?.executeAndReturnError(&failure).stringValue
                let host = value.flatMap { URL(string: $0)?.host }?.lowercased()
                return (host, failure == nil ? nil : "Allow consume:create in System Settings → Privacy & Security → Automation to track websites.")
            }.value
            browserBusy = false
            guard state.websites, active?.id == id, browserGeneration == generation else { return }
            domain = result.0
            domainReadAt = Date()
            browserStatus = result.1 ?? "Tracking domains in Safari and Chrome. Only the domain is saved."
            enforceIfNeeded()
        }
    }

    private func enforceIfNeeded(at now: Date = Date()) {
        guard state.onboardingComplete == true,
              state.blocksConsumeAutomatically,
              !state.paused,
              state.overLimit,
              let active else {
            if !state.overLimit { blockedActivity = nil }
            return
        }

        // Wait for the domain read before deciding whether a browser tab is consume or create.
        if state.websites, browserIDs.contains(active.id), domain == nil { return }

        let itemID = domain.map { "web:" + $0 } ?? active.id
        guard state.intention(for: itemID) == .consume else { return }
        guard lastEnforcedID != itemID || now.timeIntervalSince(lastEnforcedAt) >= 2 else { return }
        lastEnforcedID = itemID
        lastEnforcedAt = now

        let itemName = domain ?? active.name
        let minutes = max(1, Int(ceil(state.createSecondsToTarget / 60)))
        if let host = domain, browserIDs.contains(active.id) {
            redirectBlockedWebsite(browserID: active.id, host: host, minutes: minutes)
        } else {
            hideBlockedApplication(bundleID: active.id, name: itemName, minutes: minutes)
        }
    }

    private func hideBlockedApplication(bundleID: String, name: String, minutes: Int) {
        NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID && $0.isActive })?
            .hide()
        blockedActivity = BlockedActivity(name: name, minutesToUnlock: minutes)
        active = nil
        domain = nil
        lastTick = Date()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
    }

    private func redirectBlockedWebsite(browserID: String, host: String, minutes: Int) {
        guard let page = Bundle.main.url(forResource: "Blocked", withExtension: "html") else {
            error = "The local block page is missing."
            return
        }
        var components = URLComponents(url: page, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "name", value: host),
            URLQueryItem(name: "minutes", value: String(minutes))
        ]
        let destination = (components?.url ?? page).absoluteString
        let target = browserID == "com.apple.Safari" ? "current tab of front window" : "active tab of front window"
        let script = "tell application id \"\(browserID)\"\nif (count of windows) is 0 then return\nset URL of \(target) to \"\(destination)\"\nend tell"
        domain = nil
        browserGeneration += 1
        Task {
            let failure: String? = await Task.detached {
                var details: NSDictionary?
                NSAppleScript(source: script)?.executeAndReturnError(&details)
                return details == nil ? nil : "Allow consume:create in System Settings → Privacy & Security → Automation to block consume websites."
            }.value
            if let failure {
                browserStatus = failure
                error = failure
            }
        }
    }
}
