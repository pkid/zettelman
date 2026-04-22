import SwiftUI

enum LinearDesign {
    enum Colors {
        static let marketingBlack = Color(hex: "08090a")
        static let panelDark = Color(hex: "0f1011")
        static let level3Surface = Color(hex: "191a1b")
        static let secondarySurface = Color(hex: "28282c")

        static let primaryText = Color(hex: "f7f8f8")
        static let secondaryText = Color(hex: "dfe3eb")
        static let tertiaryText = Color(hex: "a8adb6")
        static let quaternaryText = Color(hex: "868b94")

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
            static let textSecondary = Color(hex: "dfe3eb")
            static let textTertiary = Color(hex: "a8adb6")
            static let textDisabled = Color(hex: "868b94")
            static let accent = Color(hex: "7170ff")
            static let accentHover = Color(hex: "828fff")
            static let border = Color.white.opacity(0.08)
            static let borderSubtle = Color.white.opacity(0.05)
            static let destructive = Color(hex: "eb5757")
            static let success = Color(hex: "27a644")
        }
    }

    /// All typography tokens map to semantic `Font.TextStyle` values so they
    /// scale with the user's Dynamic Type setting (Settings > Accessibility >
    /// Display & Text Size > Larger Text). This is required for App Store
    /// accessibility compliance and is what reviewers expect when evaluating
    /// legibility.
    enum Typography {
        static let display = Font.system(.largeTitle, design: .default).weight(.medium)
        static let heading1 = Font.system(.title, design: .default)
        static let heading2 = Font.system(.title2, design: .default)
        static let heading3 = Font.system(.title3, design: .default).weight(.semibold)
        static let bodyLarge = Font.system(.body, design: .default)
        static let body = Font.system(.body, design: .default)
        static let bodyMedium = Font.system(.body, design: .default).weight(.medium)
        static let bodySemibold = Font.system(.body, design: .default).weight(.semibold)
        static let small = Font.system(.subheadline, design: .default)
        static let smallMedium = Font.system(.subheadline, design: .default).weight(.medium)
        static let caption = Font.system(.footnote, design: .default)
        static let captionMedium = Font.system(.footnote, design: .default).weight(.medium)
        static let label = Font.system(.caption, design: .default)
        static let labelMedium = Font.system(.caption, design: .default).weight(.medium)
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

    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 40

    init(variant: Variant = .primary, isLoading: Bool = false) {
        self.variant = variant
        self.isLoading = isLoading
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LinearDesign.Typography.bodyMedium)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .padding(.vertical, LinearDesign.Spacing.xSmall)
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
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 40

    func body(content: Content) -> some View {
        content
            .font(LinearDesign.Typography.body)
            .foregroundStyle(LinearDesign.Colors.primaryText)
            .padding(.horizontal, LinearDesign.Spacing.medium)
            .padding(.vertical, LinearDesign.Spacing.xSmall)
            .frame(maxWidth: .infinity, minHeight: minHeight)
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
