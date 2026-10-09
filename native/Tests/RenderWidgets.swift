import SwiftUI
import AppKit

/// Render the shared widget surface at real macOS small/medium dimensions.
@main struct RenderWidgets {
    @MainActor static func main() throws {
        var healthy = UsageState()
        healthy.rules = ["input": .consume, "output": .create]
        healthy.items = ["input": UsageItem(id: "input", name: "Input", seconds: 1200), "output": UsageItem(id: "output", name: "Output", seconds: 2400)]
        var over = healthy
        over.items["input"]?.seconds = 4800
        let view = VStack(spacing: 16) {
            row(healthy)
            row(over)
            BalanceBattery(state: over, prominent: true, showsStatus: false, target: 0.45)
                .frame(width: 692, height: 250)
        }.padding(16).background(Color.gray.opacity(0.2)).environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { fatalError("Could not render widget previews") }
        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
    @MainActor static func row(_ state: UsageState) -> some View {
        HStack(spacing: 16) {
            BalanceBattery(state: state, square: true, edgeToEdge: true).frame(width: 158, height: 158).background(BalanceStyle.canvas)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            BalanceBattery(state: state, edgeToEdge: true).frame(width: 338, height: 158).background(BalanceStyle.canvas)
                .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }
}
