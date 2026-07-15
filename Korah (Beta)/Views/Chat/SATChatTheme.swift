import SwiftUI

// MARK: - SAT Chat Palette
//
// A multi-hue "category" palette borrowed from the web home page
// (korah-bot/index.html), where each tile carries its own solid accent —
// sky, emerald, gold, violet, blue — over the dark purple base.
//
// Design rule: NO gradients. Distinctiveness comes from solid tinted fills
// (~12% opacity), solid colored borders (~28% opacity) and full-strength
// colored icons/labels — the same recipe the web uses for its cards.

/// One accent hue plus its tinted surface + border, matching the web tiles.
struct SATAccent: Equatable {
    let solid: Color
    let tint: Color
    let border: Color

    init(light: Color, dark: Color) {
        self.solid = .adaptive(light: light, dark: dark)
        self.tint = .adaptive(light: light.opacity(0.10), dark: dark.opacity(0.14))
        self.border = .adaptive(light: light.opacity(0.30), dark: dark.opacity(0.32))
    }
}

extension SATAccent {
    /// #0ea5e9 / #38bdf8 — Desmos & data
    static let sky = SATAccent(
        light: Color(red: 0.055, green: 0.647, blue: 0.914),
        dark: Color(red: 0.220, green: 0.741, blue: 0.973)
    )
    /// #059669 / #10b981 — practice / correct
    static let emerald = SATAccent(
        light: Color(red: 0.020, green: 0.588, blue: 0.412),
        dark: Color(red: 0.063, green: 0.725, blue: 0.506)
    )
    /// #f59e0b / #fbbf24 — score & streaks
    static let gold = SATAccent(
        light: Color(red: 0.961, green: 0.620, blue: 0.043),
        dark: Color(red: 0.984, green: 0.749, blue: 0.141)
    )
    /// #7c3aed / #8b5cf6 — brand / reading
    static let violet = SATAccent(
        light: Color(red: 0.486, green: 0.227, blue: 0.929),
        dark: Color(red: 0.545, green: 0.361, blue: 0.965)
    )
    /// #2563eb / #3b82f6 — strategy
    static let blue = SATAccent(
        light: Color(red: 0.149, green: 0.388, blue: 0.922),
        dark: Color(red: 0.231, green: 0.510, blue: 0.965)
    )
    /// #dc2626 / #ef4444 — destructive
    static let red = SATAccent(
        light: Color(red: 0.863, green: 0.149, blue: 0.149),
        dark: Color(red: 0.937, green: 0.267, blue: 0.267)
    )

    /// Rotating palette used to color suggestion chips (mirrors the starter cards).
    static let palette: [SATAccent] = [.sky, .emerald, .gold, .violet, .blue]
}

// MARK: - Liquid Glass toolbar

extension View {
    /// Apple's Liquid Glass, tinted darker to sit over the app's deep-purple base.
    /// Falls back to a material only on OS versions without `glassEffect`.
    @ViewBuilder
    func satGlassBar(cornerRadius: CGFloat = CornerRadius.xl) -> some View {
        if #available(iOS 18.0, *) {
            self
                .glassEffect(
                    Glass.regular.tint(Color.adaptive(
                        light: Color.black.opacity(0.02),
                        dark: Color.black.opacity(0.16)
                    )),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.kBorder, lineWidth: 0.5)
                )
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.adaptive(light: .Light.surface, dark: .Dark.background).opacity(0.12))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.kBorder, lineWidth: 0.5)
                )
        }
    }
}

// MARK: - SAT Starter Prompt

/// A welcome-screen starter, each with its own category color and SF icon —
/// mirrors the SAT-specific quick prompts on the web `sat/math-chat.html`.
struct SATStarter: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let prompt: String
    let icon: String
    let accent: SATAccent

    static let all: [SATStarter] = [
        SATStarter(
            title: "Solve faster with Desmos",
            subtitle: "Graphing tricks for the math section",
            prompt: "Show me how to use the Desmos calculator to solve SAT math problems faster, with a clear example.",
            icon: "function",
            accent: .sky
        ),
        SATStarter(
            title: "Give me a practice problem",
            subtitle: "A hard SAT algebra question, step by step",
            prompt: "Give me a challenging SAT-style algebra problem and walk me through solving it step by step.",
            icon: "pencil.and.ruler",
            accent: .emerald
        ),
        SATStarter(
            title: "Boost my score",
            subtitle: "Pacing, guessing & time-saving tips",
            prompt: "What are the best strategies to raise my digital SAT score? Cover pacing, guessing, and common traps.",
            icon: "chart.line.uptrend.xyaxis",
            accent: .gold
        ),
        SATStarter(
            title: "Reading & Writing help",
            subtitle: "Evidence, grammar & vocab in context",
            prompt: "Teach me strategies for the SAT Reading & Writing section — how to handle evidence, grammar, and vocabulary-in-context questions.",
            icon: "text.book.closed",
            accent: .violet
        )
    ]
}
