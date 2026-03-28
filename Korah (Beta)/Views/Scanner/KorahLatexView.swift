import SwiftUI
import MarkdownUI
import LaTeXSwiftUI

/// Renders a message string that may contain a mix of Markdown and LaTeX math.
///
/// **How it works**
/// The string is split into alternating Markdown and math segments:
/// - `$$...$$` → display (block) math, rendered with `LaTeXSwiftUI` centered on its own line.
/// - `$...$`   → inline math, rendered with `LaTeXSwiftUI` on its own line.
/// - Everything else → rendered with MarkdownUI (supports headers, lists, bold, etc.).
///
/// **During streaming** the raw content is passed directly to `MarkdownUI` so the
/// view stays responsive. Expensive LaTeX segmentation only runs once streaming settles.
///
/// **Font sizing note (per LaTeXSwiftUI docs)**
/// `.font(.system(size:))` is documented as producing incorrect LaTeX glyph sizes.
/// `UIFont` must be passed directly to the `LaTeX` view for correct x-height measurement.
struct KorahLatexView: View {
    let content: String
    let isStreaming: Bool

    var body: some View {
        if isStreaming {
            // Show markdown as-is while tokens are arriving.
            Markdown(content)
                .markdownTheme(.korah)
        } else {
            renderedContent
        }
    }

    // MARK: - Rendered content

    @ViewBuilder
    private var renderedContent: some View {
        let segments = parseSegments(from: content)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                segmentView(for: segment)
            }
        }
    }

    @ViewBuilder
    private func segmentView(for segment: Segment) -> some View {
        switch segment {
        case .markdown(let text):
            // Trim pure-whitespace segments to avoid blank gaps in the layout.
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                Markdown(text)
                    .markdownTheme(.korah)
            }

        case .inlineMath(let latex):
            // Use SwiftUI Font here to satisfy the .font modifier type.
            LaTeX("$\(latex)$")
                .parsingMode(.onlyEquations)
                .font(.system(size: 17))
                .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))

        case .displayMath(let latex):
            // blockMode(.blockViews) renders the equation centered on its own line,
            // matching the standard LaTeX display-math presentation.
            LaTeX("$$\(latex)$$")
                .parsingMode(.onlyEquations)
                .blockMode(.blockViews)
                .font(.system(size: 17))
                .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Segment model

    private enum Segment {
        case markdown(String)
        case inlineMath(String)
        case displayMath(String)
    }

    // MARK: - Parser

    /// Splits `text` into alternating Markdown and LaTeX segments.
    ///
    /// Parsing rules (in priority order):
    /// 1. Backtick code spans and fenced code blocks are opaque — no `$` parsing inside.
    /// 2. `\$` outside math mode → literal `$` character in Markdown.
    /// 3. `$$...$$` → display math (checked before single `$`).
    /// 4. `$...$`   → inline math.
    /// 5. An unclosed math delimiter at end-of-string is auto-closed so it still renders.
    private func parseSegments(from text: String) -> [Segment] {
        var result: [Segment] = []
        var markdownBuffer = ""
        var mathBuffer = ""
        var i = text.startIndex

        var inMath = false
        var isDisplay = false
        var inCodeBlock = false
        var inInlineCode = false

        /// Appends the accumulated markdown buffer as a segment and resets it.
        func flushMarkdown() {
            guard !markdownBuffer.isEmpty else { return }
            result.append(.markdown(markdownBuffer))
            markdownBuffer = ""
        }

        /// Appends the accumulated math buffer as a segment and resets state.
        func flushMath() {
            let trimmed = mathBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                mathBuffer = ""
                return
            }
            result.append(isDisplay ? .displayMath(trimmed) : .inlineMath(trimmed))
            mathBuffer = ""
        }

        while i < text.endIndex {

            // ── Backtick runs (only outside math) ─────────────────────────────
            if !inMath && text[i] == "`" {
                var j = i
                var count = 0
                while j < text.endIndex && text[j] == "`" {
                    count += 1
                    j = text.index(after: j)
                }
                // Preserve backticks verbatim in the markdown buffer.
                markdownBuffer.append(String(repeating: "`", count: count))
                if count >= 3 && !inInlineCode {
                    inCodeBlock.toggle()
                } else if count == 1 && !inCodeBlock {
                    inInlineCode.toggle()
                }
                i = j
                continue
            }

            // ── Code content is opaque ─────────────────────────────────────────
            if inCodeBlock || inInlineCode {
                markdownBuffer.append(text[i])
                i = text.index(after: i)
                continue
            }

            // ── Escaped dollar sign (only outside math) ───────────────────────
            // Note: inside math, backslashes are LaTeX commands (\frac, \sqrt…)
            // and must not be consumed here.
            if !inMath && text[i] == "\\" {
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "$" {
                    markdownBuffer.append("$")
                    i = text.index(after: next)
                } else {
                    markdownBuffer.append("\\")
                    i = next
                }
                continue
            }

            // ── Dollar-sign delimiter logic ────────────────────────────────────
            if text[i] == "$" {
                let next = text.index(after: i)
                let isDouble = next < text.endIndex && text[next] == "$"

                if inMath {
                    let closingMatchesOpening = (isDisplay && isDouble) || (!isDisplay && !isDouble)
                    if closingMatchesOpening {
                        flushMath()
                        inMath = false
                        isDisplay = false
                        i = isDouble ? text.index(after: next) : next
                    } else {
                        // Mismatched delimiter inside math — treat as literal character.
                        mathBuffer.append("$")
                        i = next
                    }
                } else {
                    flushMarkdown()
                    inMath = true
                    isDisplay = isDouble
                    i = isDouble ? text.index(after: next) : next
                }
                continue
            }

            // ── Append character to the active buffer ─────────────────────────
            if inMath {
                mathBuffer.append(text[i])
            } else {
                markdownBuffer.append(text[i])
            }
            i = text.index(after: i)
        }

        // ── Flush any remaining content ────────────────────────────────────────
        if inMath {
            // Auto-close unclosed math so it renders rather than becoming raw text.
            flushMath()
        } else {
            flushMarkdown()
        }

        return result
    }
}

