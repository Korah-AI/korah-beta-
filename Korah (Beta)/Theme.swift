import SwiftUI

// MARK: - Legacy Color Compatibility
// These colors bridge to the new design system in DesignSystem/AppColors.swift
// Prefer using Color.adaptive() and Color.Light/Dark tokens for new code

extension Color {
    /// Legacy accent color - prefer `Color.adaptive(light: .Light.accent, dark: .Dark.accent)`
    static var korahPurple: Color {
        adaptive(light: .Light.accent, dark: .Dark.accent)
    }
    
    /// Legacy card background - prefer `Color.adaptive(light: .Light.surface, dark: .Dark.surface)`
    static var korahCardBackground: Color {
        adaptive(light: .Light.surface, dark: .Dark.surface)
    }
    
    /// Legacy gradient start
    static var korahBackgroundStart: Color {
        adaptive(light: .Light.background, dark: Color(red: 0.10, green: 0.10, blue: 0.12))
    }
    
    /// Legacy gradient end
    static var korahBackgroundEnd: Color {
        adaptive(light: .Light.backgroundSecondary, dark: Color(red: 0.16, green: 0.16, blue: 0.18))
    }
}

// MARK: - View Modifiers

extension View {
    /// Applies the Korah gradient background
    /// - Note: For new views, prefer `.kBackground()` from AppTheme.swift
    func korahGradientBackground() -> some View {
        self
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.korahBackgroundStart, .korahBackgroundEnd.opacity(0.98)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }
    
    /// Applies the Korah card style
    /// - Note: For new views, prefer `.kCard()` from AppTheme.swift
    func korahCard() -> some View {
        self
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(Color.korahCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
            )
    }
    
    /// Applies list styling consistent with Korah design
    func korahListStyle() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Text Helpers

enum KorahText {
    static func primary(_ text: Text) -> some View {
        text.foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
    }
    
    static func secondary(_ text: Text) -> some View {
        text.foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
    }
    
    static func tertiary(_ text: Text) -> some View {
        text.foregroundStyle(Color.adaptive(light: .Light.textTertiary, dark: .Dark.textTertiary))
    }
}

// MARK: - Utilities

func openedAgo(_ date: Date?) -> String {
    guard let date else { return "Never opened" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    let relative = formatter.localizedString(for: date, relativeTo: Date())
    return "Opened \(relative)"
}

// MARK: - Segmented Header

struct SegmentedHeader: View {
    @Binding var selection: Int
    private let segments = ["All", "Flashcards", "Study Guides", "Practice Tests"]
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selection) {
                ForEach(segments.indices, id: \.self) { index in
                    Text(segments[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .tint(.korahPurple)
            .padding(Spacing.md)
            .background(
                Color.adaptive(light: .Light.background, dark: .Dark.background)
            )
        }
    }
}
