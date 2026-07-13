import SwiftUI

// MARK: - Typography Scale

/// Typography system using Plus Jakarta Sans (the web app's font) with
/// Dynamic Type support. Falls back to the system font if the bundled
/// variable font fails to register.
/// Usage: .font(.kTitle), .font(.kBody), etc.
extension Font {

    /// Bundled variable-font family name (registered via UIAppFonts).
    static let kFamily = "Plus Jakarta Sans"

    /// Plus Jakarta Sans at a given size, scaling relative to a text style.
    static func jakarta(_ size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        .custom(kFamily, size: size, relativeTo: style)
    }

    // MARK: - Display

    /// Large display text (Hero sections)
    static var kLargeTitle: Font {
        jakarta(34, relativeTo: .largeTitle).weight(.bold)
    }

    // MARK: - Titles

    /// Primary title
    static var kTitle: Font {
        jakarta(28, relativeTo: .title).weight(.bold)
    }

    /// Secondary title
    static var kTitle2: Font {
        jakarta(22, relativeTo: .title2).weight(.semibold)
    }

    /// Tertiary title
    static var kTitle3: Font {
        jakarta(20, relativeTo: .title3).weight(.semibold)
    }

    // MARK: - Headlines

    /// Primary headline
    static var kHeadline: Font {
        jakarta(17, relativeTo: .headline).weight(.semibold)
    }

    /// Subheadline
    static var kSubheadline: Font {
        jakarta(15, relativeTo: .subheadline).weight(.medium)
    }

    // MARK: - Body

    /// Primary body text
    static var kBody: Font {
        jakarta(17, relativeTo: .body)
    }

    /// Body text with emphasis
    static var kBodyBold: Font {
        jakarta(17, relativeTo: .body).weight(.semibold)
    }

    // MARK: - Captions & Labels

    /// Callout text
    static var kCallout: Font {
        jakarta(16, relativeTo: .callout)
    }

    /// Footnote text
    static var kFootnote: Font {
        jakarta(13, relativeTo: .footnote)
    }

    /// Primary caption
    static var kCaption: Font {
        jakarta(12, relativeTo: .caption)
    }

    /// Secondary caption
    static var kCaption2: Font {
        jakarta(11, relativeTo: .caption2)
    }
}

// MARK: - Text Styles

extension View {
    
    /// Primary title style
    func kTitleStyle() -> some View {
        self
            .font(.kTitle)
            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
    }
    
    /// Secondary title style
    func kTitle2Style() -> some View {
        self
            .font(.kTitle2)
            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
    }
    
    /// Headline style
    func kHeadlineStyle() -> some View {
        self
            .font(.kHeadline)
            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
    }
    
    /// Body text style
    func kBodyStyle() -> some View {
        self
            .font(.kBody)
            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
    }
    
    /// Secondary text style
    func kSecondaryStyle() -> some View {
        self
            .font(.kBody)
            .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
    }
    
    /// Caption style
    func kCaptionStyle() -> some View {
        self
            .font(.kCaption)
            .foregroundStyle(Color.adaptive(light: .Light.textTertiary, dark: .Dark.textTertiary))
    }
}

// MARK: - Line Heights

extension View {
    
    /// Apply comfortable line spacing for readability
    func kLineSpacing() -> some View {
        self.lineSpacing(4)
    }
    
    /// Apply tight line spacing for compact layouts
    func kLineSpacingTight() -> some View {
        self.lineSpacing(2)
    }
    
    /// Apply loose line spacing for large text
    func kLineSpacingLoose() -> some View {
        self.lineSpacing(6)
    }
}
