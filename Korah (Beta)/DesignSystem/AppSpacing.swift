import SwiftUI

// MARK: - Spacing Scale

/// Consistent spacing scale based on 4pt grid
/// Usage: .padding(.kSpacing4), Spacing.medium, etc.
enum Spacing {
    /// 4pt - Extra small spacing
    static let xxs: CGFloat = 4
    
    /// 8pt - Small spacing
    static let xs: CGFloat = 8
    
    /// 12pt - Small-medium spacing
    static let sm: CGFloat = 12
    
    /// 16pt - Medium spacing (default)
    static let md: CGFloat = 16
    
    /// 20pt - Medium-large spacing
    static let lg: CGFloat = 20
    
    /// 24pt - Large spacing
    static let xl: CGFloat = 24
    
    /// 32pt - Extra large spacing
    static let xxl: CGFloat = 32
    
    /// 48pt - Section spacing
    static let section: CGFloat = 48
    
    // Semantic aliases
    static let tight: CGFloat = xs
    static let standard: CGFloat = md
    static let comfortable: CGFloat = xl
    static let spacious: CGFloat = xxl
}

// MARK: - Corner Radius

/// Corner radius scale for consistent rounding
enum CornerRadius {
    /// 4pt - Subtle rounding
    static let xs: CGFloat = 4
    
    /// 8pt - Small rounding
    static let sm: CGFloat = 8
    
    /// 12pt - Medium rounding
    static let md: CGFloat = 12
    
    /// 16pt - Large rounding (cards)
    static let lg: CGFloat = 16
    
    /// 20pt - Extra large rounding (modals)
    static let xl: CGFloat = 20
    
    /// 24pt - Full rounding (pills)
    static let xxl: CGFloat = 24
    
    /// Capsule/circular
    static let full: CGFloat = 9999
    
    // Semantic aliases
    static let button: CGFloat = md
    static let card: CGFloat = lg
    static let modal: CGFloat = xl
    static let pill: CGFloat = full
    static let bubble: CGFloat = xl
}

// MARK: - Padding Extensions

extension View {
    
    /// Extra small padding (4pt)
    func kPaddingXXS() -> some View {
        self.padding(Spacing.xxs)
    }
    
    /// Small padding (8pt)
    func kPaddingXS() -> some View {
        self.padding(Spacing.xs)
    }
    
    /// Small-medium padding (12pt)
    func kPaddingSM() -> some View {
        self.padding(Spacing.sm)
    }
    
    /// Medium padding (16pt) - Default
    func kPaddingMD() -> some View {
        self.padding(Spacing.md)
    }
    
    /// Large padding (20pt)
    func kPaddingLG() -> some View {
        self.padding(Spacing.lg)
    }
    
    /// Extra large padding (24pt)
    func kPaddingXL() -> some View {
        self.padding(Spacing.xl)
    }
    
    /// Section padding (32pt)
    func kPaddingXXL() -> some View {
        self.padding(Spacing.xxl)
    }
    
    /// Horizontal padding with standard spacing
    func kPaddingHorizontal(_ spacing: CGFloat = Spacing.md) -> some View {
        self.padding(.horizontal, spacing)
    }
    
    /// Vertical padding with standard spacing
    func kPaddingVertical(_ spacing: CGFloat = Spacing.md) -> some View {
        self.padding(.vertical, spacing)
    }
}

// MARK: - Hit Target

/// Minimum touch target sizes for accessibility
enum HitTarget {
    /// Minimum touch target (44pt per Apple HIG)
    static let minimum: CGFloat = 44
    
    /// Comfortable touch target
    static let comfortable: CGFloat = 48
    
    /// Large touch target
    static let large: CGFloat = 56
}

// MARK: - Component Sizes

/// Common component sizes
enum ComponentSize {
    /// Standard button height (48pt - accessible)
    static let buttonHeight: CGFloat = 48
    
    /// Standard icon button size
    static let iconButton: CGFloat = 44
    
    /// Icon sizes
    enum Icon {
        static let small: CGFloat = 16
        static let medium: CGFloat = 20
        static let large: CGFloat = 24
        static let xlarge: CGFloat = 32
    }
    
    /// Button heights
    enum Button {
        static let small: CGFloat = 36
        static let medium: CGFloat = 44
        static let large: CGFloat = 52
    }
    
    /// Avatar sizes
    enum Avatar {
        static let small: CGFloat = 32
        static let medium: CGFloat = 40
        static let large: CGFloat = 56
    }
    
    /// Input field heights
    enum Input {
        static let compact: CGFloat = 40
        static let standard: CGFloat = 48
        static let large: CGFloat = 56
    }
}

// MARK: - Stack Spacing

extension VStack {
    /// Create a VStack with standard Korah spacing
    init(kSpacing: CGFloat = Spacing.md, @ViewBuilder content: () -> Content) where Content: View {
        self.init(spacing: kSpacing, content: content)
    }
}

extension HStack {
    /// Create an HStack with standard Korah spacing
    init(kSpacing: CGFloat = Spacing.md, @ViewBuilder content: () -> Content) where Content: View {
        self.init(spacing: kSpacing, content: content)
    }
}
