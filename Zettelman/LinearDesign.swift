import SwiftUI

enum LinearDesign {
    enum Colors {
        static let marketingBlack = Color(hex: "08090a")
        static let panelDark = Color(hex: "0f1011")
        static let level3Surface = Color(hex: "191a1b")
        static let secondarySurface = Color(hex: "28282c")

        static let primaryText = Color(hex: "f7f8f8")
        static let secondaryText = Color(hex: "d0d6e0")
        static let tertiaryText = Color(hex: "8a8f98")
        static let quaternaryText = Color(hex: "62666d")

        static let brandIndigo = Color(hex: "5e6ad2")
        static let accentViolet = Color(hex: "7170ff")
        static let accentHover = Color(hex: "828fff")

        static let borderPrimary = Color(hex: "23252a")
        static let borderSecondary = Color(hex: "34343a")
        static let borderTertiary = Color(hex: "3e3e44")
        static let borderSubtle = Color.white.opacity(0.05)
        static let borderStandard = Color.white.opacity(0.08)

        static let successGreen = Color(hex: "27a644")
        static let emerald = Color(hex: "10b981")

        static let overlay = Color.black.opacity(0.85)

        enum Semantic {
            static let background = Color(hex: "0f1011")
            static let surface = Color(hex: "191a1b")
            static let surfaceHover = Color(hex: "28282c")
            static let text = Color(hex: "f7f8f8")
            static let textSecondary = Color(hex: "d0d6e0")
            static let textTertiary = Color(hex: "8a8f98")
            static let textDisabled = Color(hex: "62666d")
            static let accent = Color(hex: "7170ff")
            static let accentHover = Color(hex: "828fff")
            static let border = Color.white.opacity(0.08)
            static let borderSubtle = Color.white.opacity(0.05)
            static let destructive = Color(hex: "eb5757")
            static let success = Color(hex: "27a644")
        }
    }

    enum Typography {
        static let display = Font.system(size: 48, weight: .medium, design: .default)
        static let heading1 = Font.system(size: 32, weight: .regular, design: .default)
        static let heading2 = Font.system(size: 24, weight: .regular, design: .default)
        static let heading3 = Font.system(size: 20, weight: .semibold, design: .default)
        static let bodyLarge = Font.system(size: 18, weight: .regular, design: .default)
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 16, weight: .medium, design: .default)
        static let bodySemibold = Font.system(size: 16, weight: .semibold, design: .default)
        static let small = Font.system(size: 15, weight: .regular, design: .default)
        static let smallMedium = Font.system(size: 15, weight: .medium, design: .default)
        static let caption = Font.system(size: 13, weight: .regular, design: .default)
        static let captionMedium = Font.system(size: 13, weight: .medium, design: .default)
        static let label = Font.system(size: 12, weight: .regular, design: .default)
        static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    }

    enum Spacing {
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
        static let xxxLarge: CGFloat = 48
    }

    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 6
        static let large: CGFloat = 8
        static let xLarge: CGFloat = 12
        static let xxLarge: CGFloat = 16
    }

    enum Animation {
        static let fast: Double = 0.15
        static let normal: Double = 0.25
        static let slow: Double = 0.35
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct LinearButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case ghost
        case destructive
    }

    let variant: Variant
    let isLoading: Bool

    init(variant: Variant = .primary, isLoading: Bool = false) {
        self.variant = variant
        self.isLoading = isLoading
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LinearDesign.Typography.bodyMedium)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: LinearDesign.Radius.medium)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : (isLoading ? 0.6 : 1.0))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: LinearDesign.Animation.fast), value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return LinearDesign.Colors.accentViolet
        case .secondary:
            return Color.white.opacity(0.04)
        case .ghost:
            return Color.clear
        case .destructive:
            return LinearDesign.Colors.Semantic.destructive.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary, .ghost:
            return LinearDesign.Colors.secondaryText
        case .destructive:
            return LinearDesign.Colors.Semantic.destructive
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary:
            return Color.clear
        case .secondary:
            return LinearDesign.Colors.borderStandard
        case .ghost:
            return Color.clear
        case .destructive:
            return LinearDesign.Colors.Semantic.destructive.opacity(0.3)
        }
    }
}

struct LinearCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(LinearDesign.Colors.level3Surface)
            .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.large))
            .overlay(
                RoundedRectangle(cornerRadius: LinearDesign.Radius.large)
                    .stroke(LinearDesign.Colors.borderSubtle, lineWidth: 1)
            )
    }
}

struct LinearInputFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(LinearDesign.Typography.body)
            .foregroundStyle(LinearDesign.Colors.primaryText)
            .padding(.horizontal, LinearDesign.Spacing.medium)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: LinearDesign.Radius.medium)
                    .stroke(LinearDesign.Colors.borderStandard, lineWidth: 1)
            )
    }
}

extension View {
    func linearCard() -> some View {
        modifier(LinearCardStyle())
    }

    func linearInputField() -> some View {
        modifier(LinearInputFieldStyle())
    }
}
