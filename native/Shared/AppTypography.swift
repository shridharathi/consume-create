import SwiftUI
import CoreText

enum AppTypography {
    enum Weight {
        case regular, medium, semibold

        var postScriptName: String {
            switch self {
            case .regular: "Archivo-Regular"
            case .medium: "Archivo-Medium"
            case .semibold: "Archivo-SemiBold"
            }
        }
    }

    private static let registration: Void = {
        for name in ["Archivo-Regular", "Archivo-Medium", "Archivo-SemiBold", "Silkscreen-Regular", "Silkscreen-Bold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func font(_ size: CGFloat, weight: Weight = .regular) -> Font {
        _ = registration
        return .custom(weight.postScriptName, size: size)
    }

    /// Pixel display face reserved for the product mark and short visual headings.
    static func display(_ size: CGFloat, bold: Bool = false) -> Font {
        _ = registration
        return .custom(bold ? "Silkscreen-Bold" : "Silkscreen-Regular", size: size)
    }

    static let caption2 = font(10)
    static let caption = font(11)
    static let callout = font(13)
    static let body = font(14)
    static let headline = font(16, weight: .semibold)
    static let title2 = font(22)
}
