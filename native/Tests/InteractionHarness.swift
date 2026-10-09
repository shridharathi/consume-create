import SwiftUI

/// Standalone UI check: no tracker, shared container, permissions, or saved user data.
@main struct InteractionHarness: App {
    var body: some Scene {
        Window("consume:create · Interaction check", id: "check") {
            HarnessContent()
        }.defaultSize(width: 760, height: 700)
    }
}

private struct HarnessContent: View {
    @State private var rules = IntentionItem.startingRules([:])
    @State private var ratio = 0.5
    @State private var tab = 0
    var body: some View {
        VStack(spacing: 20) {
            Picker("Check", selection: $tab) {
                Text("Cards").tag(0)
                Text("Ratio").tag(1)
            }.pickerStyle(.segmented)
            if tab == 0 {
                ClassificationBoard(state: UsageState(), rules: $rules)
            } else { RatioEditor(ratio: $ratio) }
            Spacer(minLength: 0)
        }.padding(32).frame(width: 760, height: 700)
            .background(Color(red: 0.985, green: 0.982, blue: 0.965)).preferredColorScheme(.light)
    }
}
