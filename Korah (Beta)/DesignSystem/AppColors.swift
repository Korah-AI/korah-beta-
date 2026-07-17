import SwiftUI

// MARK: - Color Tokens

/// Semantic color tokens that adapt to light/dark mode.
/// Mirrors the web app's korah.css [data-theme] variables exactly.
/// Usage: Color.kBackground, Color.kSurface, etc.
extension Color {

    // MARK: - Backgrounds (--bg / --bg2 / --bg3)

    static var kBackground: Color {
        .adaptive(light: .Light.background, dark: .Dark.background)
    }

    static var kBackgroundSecondary: Color {
        .adaptive(light: .Light.backgroundSecondary, dark: .Dark.backgroundSecondary)
    }

    // MARK: - Surfaces (--sf / --sf2)

    static var kSurface: Color {
        .adaptive(light: .Light.surface, dark: .Dark.surface)
    }

    static var kSurfaceElevated: Color {
        .adaptive(light: .Light.surfaceElevated, dark: .Dark.surfaceElevated)
    }

    // MARK: - Text (--tx / --tx2 / --tx3)

    static var kTextPrimary: Color {
        .adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary)
    }

    static var kTextSecondary: Color {
        .adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary)
    }

    static var kTextTertiary: Color {
        .adaptive(light: .Light.textTertiary, dark: .Dark.textTertiary)
    }

    // MARK: - Accent (--p4 / --p5 / --ac)

    static var kAccent: Color {
        .adaptive(light: .Light.accent, dark: .Dark.accent)
    }

    /// Lighter accent variant (--p5)
    static var kAccentLight: Color {
        .adaptive(light: .Light.accentLight, dark: .Dark.accentLight)
    }

    /// Pink/fuchsia accent used in gradient text (--ac)
    static var kAccentAlt: Color {
        .adaptive(light: Color(red: 0.635, green: 0.110, blue: 0.686),   // #a21caf
                  dark: Color(red: 0.941, green: 0.671, blue: 0.988))    // #f0abfc
    }

    static var kAccentUser: Color {
        .adaptive(light: .Light.accentUser, dark: .Dark.accentUser)
    }

    static var kAccentAssistant: Color {
        .adaptive(light: .Light.accentAssistant, dark: .Dark.accentAssistant)
    }

    /// Bold blue used for the selected tab bar item (blue-600 / blue-500).
    static var kTabBarSelected: Color {
        .adaptive(light: Color(red: 0.145, green: 0.388, blue: 0.922),   // #2563eb
                  dark: Color(red: 0.231, green: 0.510, blue: 0.965))    // #3b82f6
    }

    // MARK: - Semantic (--grn / --gold / --red)

    static var kSuccess: Color {
        .adaptive(light: .Light.success, dark: .Dark.success)
    }

    static var kWarning: Color {
        .adaptive(light: .Light.warning, dark: .Dark.warning)
    }

    /// Gold accent (--gold), same as kWarning but named to match the web token
    static var kGold: Color { kWarning }

    static var kError: Color {
        .adaptive(light: .Light.error, dark: .Dark.error)
    }

    // MARK: - Mood (--mg / --my / --mr)

    static var kMoodGreen: Color {
        .adaptive(light: Color(red: 0.086, green: 0.639, blue: 0.290),   // #16a34a
                  dark: Color(red: 0.133, green: 0.773, blue: 0.369))    // #22c55e
    }

    static var kMoodYellow: Color {
        .adaptive(light: Color(red: 0.792, green: 0.541, blue: 0.016),   // #ca8a04
                  dark: Color(red: 0.918, green: 0.702, blue: 0.031))    // #eab308
    }

    static var kMoodRed: Color {
        .adaptive(light: Color(red: 0.863, green: 0.149, blue: 0.149),   // #dc2626
                  dark: Color(red: 0.937, green: 0.267, blue: 0.267))    // #ef4444
    }

    // MARK: - Separators, Borders & Glow (--bd / --bd2 / --glow)

    static var kSeparator: Color {
        .adaptive(light: .Light.separator, dark: .Dark.separator)
    }

    static var kBorder: Color {
        .adaptive(light: .Light.border, dark: .Dark.border)
    }

    static var kGlow: Color {
        .adaptive(light: .Light.glow, dark: .Dark.glow)
    }
}

// MARK: - Fallback Colors (for when Asset Catalog colors aren't available)

extension Color {
    
    /// Light mode color palette (Updated to match web theme)
    enum Light {
        // Backgrounds - Light purple tints
        static let background = Color(red: 0.980, green: 0.973, blue: 1.0)         // #faf8ff
        static let backgroundSecondary = Color(red: 0.953, green: 0.937, blue: 1.0) // #f3efff
        static let surface = Color.white
        static let surfaceElevated = Color.white
        
        // Text - Dark purple tints
        static let textPrimary = Color(red: 0.102, green: 0.039, blue: 0.235)      // #1a0a3c
        static let textSecondary = Color(red: 0.353, green: 0.290, blue: 0.478)    // #5a4a7a
        static let textTertiary = Color(red: 0.565, green: 0.502, blue: 0.667)     // #9080aa
        
        // Accent - Purple from web (#7c3aed lighter variant)
        static let accent = Color(red: 0.486, green: 0.227, blue: 0.929)          // #7c3aed
        static let accentLight = Color(red: 0.545, green: 0.361, blue: 0.965)     // #8b5cf6
        static let accentUser = Color(red: 0.486, green: 0.227, blue: 0.929)
        static let accentAssistant = Color(red: 0.953, green: 0.937, blue: 1.0)   // Light surface
        
        // Semantic colors
        static let success = Color(red: 0.024, green: 0.588, blue: 0.412)         // #059669
        static let warning = Color(red: 0.851, green: 0.541, blue: 0.024)         // #d97706
        static let error = Color(red: 0.863, green: 0.149, blue: 0.149)           // #dc2626
        static let info = Color(red: 0.486, green: 0.227, blue: 0.929)
        
        // Borders & Separators
        static let separator = Color(red: 0.427, green: 0.157, blue: 0.851).opacity(0.1)  // Purple-tinted
        static let border = Color(red: 0.427, green: 0.157, blue: 0.851).opacity(0.18)    // Purple-tinted
        
        // Glow effect color
        static let glow = Color(red: 0.427, green: 0.157, blue: 0.851).opacity(0.15)      // Softer glow for light mode
    }
    
    /// Dark mode color palette (Updated to match web theme - brightened)
    enum Dark {
        // Backgrounds - Brighter purple-black scheme
        static let background = Color(red: 0.047, green: 0.035, blue: 0.102)        // Brightened from #06040f
        static let backgroundSecondary = Color(red: 0.071, green: 0.055, blue: 0.157) // Brightened from #0d0920
        static let surface = Color(red: 0.098, green: 0.071, blue: 0.196)           // Brightened from #120c28
        static let surfaceElevated = Color(red: 0.149, green: 0.106, blue: 0.275)  // Brighter variant
        
        // Text - From web theme (#f0eaff, #a89dc0, #6b5f88)
        static let textPrimary = Color(red: 0.941, green: 0.918, blue: 1.0)        // #f0eaff
        static let textSecondary = Color(red: 0.659, green: 0.616, blue: 0.753)    // #a89dc0
        static let textTertiary = Color(red: 0.420, green: 0.373, blue: 0.533)     // #6b5f88
        
        // Accent - Purple gradient from web (#8b5cf6, #a78bfa)
        static let accent = Color(red: 0.545, green: 0.361, blue: 0.965)          // #8b5cf6
        static let accentLight = Color(red: 0.655, green: 0.545, blue: 0.980)     // #a78bfa
        static let accentUser = Color(red: 0.545, green: 0.361, blue: 0.965)      // Same as accent
        static let accentAssistant = Color(red: 0.071, green: 0.047, blue: 0.157) // Dark surface
        
        // Semantic colors
        static let success = Color(red: 0.204, green: 0.831, blue: 0.600)         // #34d399 (green)
        static let warning = Color(red: 0.984, green: 0.749, blue: 0.141)         // #fbbf24 (gold)
        static let error = Color(red: 0.973, green: 0.443, blue: 0.443)           // #f87171 (red)
        static let info = Color(red: 0.545, green: 0.361, blue: 0.965)            // Same as accent
        
        // Borders & Separators - Purple-tinted from web
        static let separator = Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.1)  // rgba(139,92,246,.1)
        static let border = Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.2)     // rgba(139,92,246,.2)
        
        // Glow effect color
        static let glow = Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.35)      // rgba(139,92,246,.35)
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
    
    /// Accent gradient for buttons and highlights (Purple gradient from web: #5b21b6 → #8b5cf6)
    static var kAccentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.357, green: 0.129, blue: 0.714),  // #5b21b6
                Color(red: 0.545, green: 0.361, blue: 0.965)   // #8b5cf6
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Purple gradient for user message bubbles (same as accent)
    static var kPurpleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.357, green: 0.129, blue: 0.714),  // #5b21b6
                Color(red: 0.545, green: 0.361, blue: 0.965)   // #8b5cf6
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Gradient Text & Radial Glow (web .grad-text / .radial-glow-bg)

extension LinearGradient {

    /// Gradient used for headline text (web: linear-gradient(135deg, var(--p4), var(--ac)))
    static var kTextGradient: LinearGradient {
        LinearGradient(
            colors: [Color.kAccent, Color.kAccentAlt],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {

    /// Renders text with the accent→pink gradient and a soft glow,
    /// matching the web's `.grad-text` class.
    func kGradientText() -> some View {
        self
            .foregroundStyle(LinearGradient.kTextGradient)
            .shadow(color: Color.kGlow, radius: 12)
    }

    /// Radial purple glow backdrop, matching the web's `.radial-glow-bg`.
    func kRadialGlowBackground(radius: CGFloat = 180) -> some View {
        self.background(
            RadialGradient(
                colors: [Color.kGlow, .clear],
                center: .center,
                startRadius: 0,
                endRadius: radius
            )
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
    
    /// Purple glow shadow (matches web theme glow effect)
    func kShadowGlow() -> some View {
        self.shadow(
            color: Color.adaptive(light: .Light.glow, dark: .Dark.glow),
            radius: 20,
            x: 0,
            y: 6
        )
    }
    
    /// Large purple glow shadow for prominent elements
    func kShadowGlowLarge() -> some View {
        self.shadow(
            color: Color.adaptive(light: .Light.glow, dark: .Dark.glow),
            radius: 36,
            x: 0,
            y: 12
        )
    }
}
