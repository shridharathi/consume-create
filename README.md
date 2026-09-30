# consume:create

A native macOS 14+ menu bar app and WidgetKit desktop widget for balancing consumption and creation. The earlier HTML/CSS prototype is retained at the repository root; the shipping implementation is in `native/`.

## Run on this Mac

Open `native/ConsumeCreate.xcodeproj`, select the **ConsumeCreate** scheme, and run with **My Mac** as the destination. Or build from Terminal:

```sh
cd native
xcodebuild -project ConsumeCreate.xcodeproj -scheme ConsumeCreate \
  -configuration Release -derivedDataPath build build
open build/Build/Products/Release/consume-create.app
```

The project uses the development certificate already installed on this Mac. To build on a different Mac, set your own signing team and a matching team-prefixed `CONSUME_CREATE_GROUP` in both targets. `native/project.yml` is the source for the Xcode project; regenerate with `cd native && xcodegen generate` after changing it.

For ongoing use, copy the built app into your Applications folder before enabling **Open at login**. Keep the app running; closing its window leaves the menu bar tracker active. Quitting stops tracking.

## Add the desktop widget

1. Launch consume:create once and follow the welcome flow.
2. Right-click the desktop and choose **Edit Widgets**.
3. Search for **consume:create** and add the small square or medium horizontal widget.
4. Click the widget to open your day. **Edit apps & websites** opens two draggable columns, and the target line on the dashboard battery adjusts the daily goal.

## First-run setup

The welcome flow has three steps: welcome, sort apps/websites into consume and create, and drag the battery divider to set a goal. A final confirmation offers optional browser access and reminders. Cards have move arrows and keyboard-accessible menus as alternatives to dragging; the battery has presets and accessibility increment/decrement actions. You can rerun welcome from Preferences.

Existing activity, classifications, notification settings, and goals survive upgrades through the shared App Group store.

The fill is consumption / (consumption + creation). The battery turns red strictly above the chosen limit. Unknown apps are ignored until classified. Reclassifying an app immediately updates today's totals.

## Tracking and permissions

- Tracks the foreground application locally, sampling every two seconds. Ignores consume:create itself. Stops while paused, asleep, screen-locked, or inactive for 60 seconds. Long sampling gaps aren't charged as usage.
- Safari and Google Chrome domain tracking is optional. Turn it on in Settings, activate a supported browser, and approve macOS Automation access. Active domains are sampled about every five seconds; app/tab transitions have that sampling granularity. If access fails, the app shows an explanation and falls back to the browser's app rule. An observed website gets its own rule, with parent-domain rules applying to subdomains; an unmatched website is ignored.
- Website tracking can observe domains in private browser windows too. Leave it off or pause tracking when you want those sessions excluded. Full URLs, titles, page contents, keystrokes, and screenshots are never saved.
- Notifications are opt-in. The first nudge requires five minutes of classified activity; further nudges require a new threshold crossing and a 30-minute cooldown. Notification permission is controlled by macOS.
- Automatic blocking is on by default and can be disabled in Preferences. When the ratio is over target, consume apps are hidden and consume tabs in connected Safari or Chrome sessions are replaced with a bundled local pause page. No browsing data is sent to a server.
- Startup at login uses Apple's ServiceManagement registration and is opt-in.
- Usage rolls over at local midnight. Compact daily summaries are retained locally for up to two years and appear in the in-app calendar; data from versions before calendar history was introduced cannot be reconstructed. Rules and settings persist. The app does not import Apple Screen Time history.
- The app writes an atomic JSON snapshot in its shared App Group container (`M325QUK9MT.com.counterbalance.shared/balance.json`). The extension only reads it. No backend or cloud workers are needed.

Desktop widgets are snapshots: macOS controls their refresh budget. The app requests periodic refreshes (15 minutes) and refreshes on threshold crossings or settings changes. The menu bar is the live view. See [Apple's widget refresh documentation](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/).

## Verification

```sh
swiftc native/Shared/Usage.swift native/Tests/UsageTests.swift -o /tmp/counterbalance-usage-tests
/tmp/counterbalance-usage-tests
codesign --verify --deep --strict native/build/Build/Products/Release/consume-create.app
pluginkit -m -A -D -i com.consumecreate.mac.widget
```

The model checks cover ratio/threshold math, automatic blocking state, calendar history, ignored time, pause, long idle/sleep gaps, domain-boundary matching, retroactive classification, midnight splitting, and persistence encoding. This is a development-signed local build, not a notarized public distribution.
