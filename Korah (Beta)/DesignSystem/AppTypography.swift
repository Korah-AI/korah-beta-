import SwiftUI

// MARK: - Typography Scale

/// Typography system using SF Pro with Dynamic Type support
/// Usage: .font(.kTitle), .font(.kBody), etc.
extension Font {
    
    // MARK: - Display
    
    /// Large display text (Hero sections)
    static var kLargeTitle: Font {
        .largeTitle.weight(.bold)
    }
    
    // MARK: - Titles
    
    /// Primary title
    static var kTitle: Font {
        .title.weight(.bold)
    }
    
    /// Secondary title
    static var kTitle2: Font {
        .title2.weight(.semibold)
    }
    
    /// Tertiary title
    static var kTitle3: Font {
        .title3.weight(.semibold)
    }
    
    // MARK: - Headlines
    
    /// Primary headline
    static var kHeadline: Font {
        .headline.weight(.semibold)
    }
    
    /// Subheadline
    static var kSubheadline: Font {
        .subheadline.weight(.medium)
    }
    
    // MARK: - Body
    
    /// Primary body text
    static var kBody: Font {
        .body
    }
    
    /// Body text with emphasis
    static var kBodyBold: Font {
        .body.weight(.semibold)
    }
    
    // MARK: - Captions & Labels
    
    /// Callout text
    static var kCallout: Font {
        .callout
    }
    
    /// Footnote text
    static var kFootnote: Font {
        .footnote
    }
    
    /// Primary caption
    static var kCaption: Font {
        .caption
    }
    
    /// Secondary caption
    static var kCaption2: Font {
        .caption2
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
