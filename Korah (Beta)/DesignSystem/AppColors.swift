import SwiftUI

// MARK: - Color Tokens

/// Semantic color tokens that adapt to light/dark mode
/// Usage: Color.kBackground, Color.kSurface, etc.
extension Color {
    
    // MARK: - Backgrounds
    
    /// Primary background color (near-white in light, charcoal in dark)
    static var kBackground: Color {
        Color("kBackground", bundle: nil)
    }
    
    /// Secondary background for elevated surfaces
    static var kBackgroundSecondary: Color {
        Color("kBackgroundSecondary", bundle: nil)
    }
    
    // MARK: - Surfaces
    
    /// Card and elevated surface background
    static var kSurface: Color {
        Color("kSurface", bundle: nil)
    }
    
    /// Elevated surface (modals, sheets)
    static var kSurfaceElevated: Color {
        Color("kSurfaceElevated", bundle: nil)
    }
    
    // MARK: - Text
    
    /// Primary text color
    static var kTextPrimary: Color {
        Color("kTextPrimary", bundle: nil)
    }
    
    /// Secondary/muted text color
    static var kTextSecondary: Color {
        Color("kTextSecondary", bundle: nil)
    }
    
    /// Tertiary/placeholder text color
    static var kTextTertiary: Color {
        Color("kTextTertiary", bundle: nil)
    }
    
    // MARK: - Accent
    
    /// Primary accent color (purple)
    static var kAccent: Color {
        Color("kAccent", bundle: nil)
    }
    
    /// Accent color for user messages in chat
    static var kAccentUser: Color {
        Color("kAccentUser", bundle: nil)
    }
    
    /// Accent color for assistant messages in chat
    static var kAccentAssistant: Color {
        Color("kAccentAssistant", bundle: nil)
    }
    
    // MARK: - Semantic
    
    /// Success color (green)
    static var kSuccess: Color {
        Color("kSuccess", bundle: nil)
    }
    
    /// Warning color (yellow/orange)
    static var kWarning: Color {
        Color("kWarning", bundle: nil)
    }
    
    /// Error/destructive color (red)
    static var kError: Color {
        Color("kError", bundle: nil)
    }
    
    // MARK: - Separators & Borders
    
    /// Separator/divider color
    static var kSeparator: Color {
        Color("kSeparator", bundle: nil)
    }
    
    /// Border color for cards and inputs
    static var kBorder: Color {
        Color("kBorder", bundle: nil)
    }
}

// MARK: - Fallback Colors (for when Asset Catalog colors aren't available)

extension Color {
    
    /// Light mode color palette
    enum Light {
        static let background = Color(red: 0.98, green: 0.98, blue: 0.99)
        static let backgroundSecondary = Color(red: 0.95, green: 0.95, blue: 0.97)
        static let surface = Color.white
        static let surfaceElevated = Color.white
        static let textPrimary = Color(red: 0.1, green: 0.1, blue: 0.12)
        static let textSecondary = Color(red: 0.4, green: 0.4, blue: 0.45)
        static let textTertiary = Color(red: 0.6, green: 0.6, blue: 0.65)
        static let accent = Color(red: 0.58, green: 0.35, blue: 0.98)
        static let accentUser = Color(red: 0.58, green: 0.35, blue: 0.98)
        static let accentAssistant = Color(red: 0.95, green: 0.95, blue: 0.97)
        static let success = Color(red: 0.2, green: 0.78, blue: 0.35)
        static let warning = Color(red: 1.0, green: 0.76, blue: 0.03)
        static let error = Color(red: 1.0, green: 0.27, blue: 0.23)
        static let info = Color(red: 0.2, green: 0.5, blue: 1.0)
        static let separator = Color(red: 0.9, green: 0.9, blue: 0.92)
        static let border = Color(red: 0.85, green: 0.85, blue: 0.88)
    }
    
    /// Dark mode color palette
    enum Dark {
        static let background = Color(red: 0.08, green: 0.08, blue: 0.10)
        static let backgroundSecondary = Color(red: 0.12, green: 0.12, blue: 0.14)
        static let surface = Color(red: 0.14, green: 0.14, blue: 0.16)
        static let surfaceElevated = Color(red: 0.18, green: 0.18, blue: 0.20)
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.75)
        static let textTertiary = Color(red: 0.5, green: 0.5, blue: 0.55)
        static let accent = Color(red: 0.68, green: 0.45, blue: 1.0)
        static let accentUser = Color(red: 0.68, green: 0.45, blue: 1.0)
        static let accentAssistant = Color(red: 0.18, green: 0.18, blue: 0.22)
        static let success = Color(red: 0.3, green: 0.85, blue: 0.45)
        static let warning = Color(red: 1.0, green: 0.82, blue: 0.1)
        static let error = Color(red: 1.0, green: 0.37, blue: 0.33)
        static let info = Color(red: 0.35, green: 0.6, blue: 1.0)
        static let separator = Color(red: 0.25, green: 0.25, blue: 0.28)
        static let border = Color(red: 0.3, green: 0.3, blue: 0.33)
    }
}

// MARK: - Adaptive Colors (Programmatic light/dark)

extension Color {
    
    /// Creates an adaptive color that changes based on color scheme
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Gradients

extension LinearGradient {
    
    /// Primary background gradient
    static var kBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.adaptive(light: .Light.background, dark: .Dark.background),
                Color.adaptive(light: .Light.backgroundSecondary, dark: .Dark.backgroundSecondary)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Accent gradient for buttons and highlights
    static var kAccentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.adaptive(light: .Light.accent, dark: .Dark.accent),
                Color.adaptive(light: .Light.accent.opacity(0.8), dark: .Dark.accent.opacity(0.8))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Shadow Styles

extension View {
    
    /// Subtle shadow for cards
    func kShadowSubtle() -> some View {
        self.shadow(
            color: Color.black.opacity(0.06),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    /// Medium shadow for elevated surfaces
    func kShadowMedium() -> some View {
        self.shadow(
            color: Color.black.opacity(0.1),
            radius: 16,
            x: 0,
            y: 8
        )
    }
    
    /// Strong shadow for modals and popovers
    func kShadowStrong() -> some View {
        self.shadow(
            color: Color.black.opacity(0.15),
            radius: 24,
            x: 0,
            y: 12
        )
    }
    
    /// Accent glow shadow
    func kShadowAccent() -> some View {
        self.shadow(
            color: Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.3),
            radius: 12,
            x: 0,
            y: 4
        )
    }
}
