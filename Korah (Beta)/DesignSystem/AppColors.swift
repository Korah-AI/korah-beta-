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
