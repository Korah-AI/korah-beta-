import SwiftUI

// MARK: - Theme Mode

/// App appearance mode selection
enum ThemeMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Theme Manager

/// Observable theme manager for app-wide appearance control
@MainActor
@Observable
final class ThemeManager {
    
    /// Shared instance for app-wide access
    static let shared = ThemeManager()
    
    /// Current theme mode (persisted)
    var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "AppThemeMode")
        }
    }
    
    /// Whether to use true black for OLED dark mode
    var useTrueBlack: Bool {
        didSet {
            UserDefaults.standard.set(useTrueBlack, forKey: "AppUseTrueBlack")
        }
    }
    
    /// Current color scheme based on theme mode
    var colorScheme: ColorScheme? {
        themeMode.colorScheme
    }
    
    private init() {
        // Load saved preferences
        let savedMode = UserDefaults.standard.string(forKey: "AppThemeMode") ?? "System"
        self.themeMode = ThemeMode(rawValue: savedMode) ?? .system
        self.useTrueBlack = UserDefaults.standard.bool(forKey: "AppUseTrueBlack")
    }
}

// MARK: - Theme View Modifier

struct ThemeModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeManager.colorScheme)
    }
}

extension View {
    /// Apply theme settings to this view
    func withTheme() -> some View {
        self.modifier(ThemeModifier())
    }
}

// MARK: - Modern Background Modifiers

extension View {
    
    /// Apply the modern Korah background gradient
    func kBackground(withStars: Bool = false) -> some View {
        self.background(
            Group {
                if withStars {
                    TwinklingStarsBackground(starCount: 80)
                } else {
                    LinearGradient.kBackgroundGradient
                        .ignoresSafeArea()
                }
            }
        )
    }
    
    /// Apply a surface background for cards
    func kSurfaceBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
        )
    }
    
    /// Apply an elevated surface background
    func kElevatedBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.adaptive(light: .Light.surfaceElevated, dark: .Dark.surfaceElevated))
        )
        .kShadowSubtle()
    }
    
    /// Apply glass effect with purple tint (uses Apple's Liquid Glass on iOS 18+)
    func kGlassEffect(cornerRadius: CGFloat = CornerRadius.card, interactive: Bool = false) -> some View {
        Group {
            if #available(iOS 18.0, *) {
                // Use Apple's official Liquid Glass effect with subtle purple tint
                self
                    .background(
                        Color.adaptive(light: .Light.surface, dark: .Dark.surface).opacity(0.02)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border).opacity(0.3), lineWidth: 0.5)
                    )
                    .glassEffect(
                        interactive ? 
                            Glass.regular.tint(Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.15)).interactive() : 
                            Glass.regular.tint(Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.15)),
                        in: .rect(cornerRadius: cornerRadius)
                    )
            } else {
                // Fallback for iOS 17 and earlier with subtle purple tint
                self
                    .background(
                        ZStack {
                            // Ultra thin material for glass effect
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(.ultraThinMaterial)
                            
                            // Very subtle purple-tinted overlay
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface).opacity(0.1))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border).opacity(0.3), lineWidth: 0.5)
                    )
            }
        }
    }
}

// MARK: - Modern Card Modifier

extension View {
    
    /// Apply modern card styling with glass effect
    func kCard(cornerRadius: CGFloat = CornerRadius.card, interactive: Bool = false) -> some View {
        self
            .padding(Spacing.md)
            .kGlassEffect(cornerRadius: cornerRadius, interactive: interactive)
            .kShadowSubtle()
    }
    
    /// Apply accent card styling
    func kAccentCard() -> some View {
        self
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
            )
            .kShadowAccent()
    }
}

// MARK: - Button Styles

/// Modern primary button style (with purple gradient and glow from web theme)
struct KPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: ComponentSize.Button.medium)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button, style: .continuous)
                    .fill(LinearGradient.kPurpleGradient)
            )
            .kShadowGlow()
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Modern secondary button style
struct KSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kHeadline)
            .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
            .frame(maxWidth: .infinity)
            .frame(height: ComponentSize.Button.medium)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button, style: .continuous)
                    .fill(Color.adaptive(light: .Light.accent.opacity(0.1), dark: .Dark.accent.opacity(0.15)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.button, style: .continuous)
                    .stroke(Color.adaptive(light: .Light.accent.opacity(0.3), dark: .Dark.accent.opacity(0.3)), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Modern ghost/text button style
struct KGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kSubheadline)
            .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == KPrimaryButtonStyle {
    static var kPrimary: KPrimaryButtonStyle { KPrimaryButtonStyle() }
}

extension ButtonStyle where Self == KSecondaryButtonStyle {
    static var kSecondary: KSecondaryButtonStyle { KSecondaryButtonStyle() }
}

extension ButtonStyle where Self == KGhostButtonStyle {
    static var kGhost: KGhostButtonStyle { KGhostButtonStyle() }
}

/// Glass button style using Apple's liquid glass (iOS 18+) or fallback
struct KGlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kHeadline)
            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .kGlassEffect(cornerRadius: CornerRadius.button, interactive: true)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == KGlassButtonStyle {
    static var kGlass: KGlassButtonStyle { KGlassButtonStyle() }
}

// MARK: - Haptics

enum Haptics {
    
    /// Light impact feedback
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Medium impact feedback
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Success feedback
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Error feedback
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    /// Selection feedback
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Animation Constants

enum KAnimation {
    /// Quick spring animation for interactions
    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Standard spring animation
    static let standard = Animation.spring(response: 0.4, dampingFraction: 0.75)
    
    /// Smooth spring animation for larger movements
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.8)
    
    /// Bouncy spring for playful interactions
    static let bouncy = Animation.spring(response: 0.35, dampingFraction: 0.6)
}

// MARK: - Glass Effect Container Helper

/// Container for multiple glass effects (uses Apple's GlassEffectContainer on iOS 18+)
struct KGlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 20.0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        if #available(iOS 18.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            // Fallback for iOS 17 and earlier - just render content normally
            content
        }
    }
}
