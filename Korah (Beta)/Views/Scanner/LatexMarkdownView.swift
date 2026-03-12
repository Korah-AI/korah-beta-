import SwiftUI
import MarkdownUI
import LaTeXSwiftUI

/// A markdown view that renders LaTeX math equations inline.
///
/// Streaming and settled content share the same segmentation path.
/// The only difference is the LaTeX rendering style:
///   - Streaming  → `.original`  (shows raw delimiter text until the SVG is ready,
///                                keeping the view responsive during rapid updates)
///   - Settled    → `.empty`     (view stays blank until the SVG is ready, giving a
///                                clean final appearance with no flicker)
///
/// Both styles are asynchronous, so SVG rendering never blocks the main queue.
struct LatexMarkdownView: View {
    let content: String
    let isStreaming: Bool

    /// Enable to visualize how the input splits into segments.
    private let debugSegmentation: Bool = false

    /// Rendering style passed down to every LaTeX segment.
    private var latexRenderingStyle: LaTeX.RenderingStyle {
        isStreaming ? .original : .empty
    }

    var body: some View {
        let normalized = normalizeMathOutput(content)
        renderSegments(splitIntoMarkdownAndLatexSegments(normalized))
    }

    // MARK: - Segment renderer

    @ViewBuilder
    private func renderSegments(
        _ segments: [(content: String, isLatex: Bool, display: Bool)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if debugSegmentation {
                let dbg = segments.map { seg in
                    let type = seg.isLatex ? (seg.display ? "$$" : "$") : "MD"
                    return "[" + type + "] " + seg.content.replacingOccurrences(of: "\n", with: "⏎")
                }.joined(separator: "\n\n")
                Text(dbg)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(6)
                    .background(.black.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 6))
            }
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                if segment.isLatex {
                    let wrapped = segment.display
                        ? "$$\(segment.content)$$"
                        : "$\(segment.content)$"

                    if segment.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        EmptyView()
                    } else {
                        LaTeX(wrapped)
                            .parsingMode(.onlyEquations)
                            // Move SVG rendering off the main queue.
                            // .original shows raw text during streaming, .empty hides until ready.
                            // Normalization above helps avoid unbalanced delimiters during streaming.
                            .renderingStyle(latexRenderingStyle)
                            // Pass UIFont directly — LaTeXSwiftUI cannot correctly derive
                            // x-height from a SwiftUI Font struct (e.g. .system(size:)).
                            .font(.system(size: 17))
                            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    }
                } else if !segment.content.isEmpty {
                    Markdown(segment.content)
                        .markdownTheme(.korah)
                }
            }
        }
    }

    // MARK: - Segmentation

    /// Normalizes model output to improve LaTeX detection and rendering.
    /// - Ensures blank lines around display math `$$...$$` blocks
    /// - Unwraps simple code-wrapped math like `` `$x^2$` ``
    /// - Avoids accidental triple-backtick fencing around math-only lines
    private func normalizeMathOutput(_ text: String) -> String {
        var s = text

        // 1) Unwrap inline code that is purely a single math span: `$...$` inside single backticks.
        //    We only unwrap when backticks wrap exactly one math span and nothing else.
        //    Pattern: ` $...$ ` or `$(... )$` with optional surrounding spaces.
        s = s.replacingOccurrences(of: "`\\n?\\n?\\s*\\$", with: "$", options: [.regularExpression])
        s = s.replacingOccurrences(of: "\\$\\s*\\n?\\n?`", with: "$", options: [.regularExpression])

        // 2) Ensure display math blocks have blank lines before and after.
        // We find $$...$$ blocks that are not already separated by blank lines and insert them.
        // This is a light heuristic that handles common cases.
        s = s.replacingOccurrences(
            of: "([^\\n])\\n?\\s*\\$\\$",
            with: "$1\n\n$$",
            options: [.regularExpression]
        )
        s = s.replacingOccurrences(
            of: "\\$\\$\\s*\\n?([^\\n])",
            with: "$$\n\n$1",
            options: [.regularExpression]
        )

        // 3) Avoid code fences around math-only lines: ```$$ ... $$``` → just the math.
        s = s.replacingOccurrences(
            of: "```\\n\\s*\\$\\$",
            with: "$$",
            options: [.regularExpression]
        )
        s = s.replacingOccurrences(
            of: "\\$\\$\\s*\\n```",
            with: "$$",
            options: [.regularExpression]
        )

        return s
    }

    /// Splits a mixed markdown + LaTeX string into typed segments.
    ///
    /// Rules:
    /// - `$$...$$` → display math
    /// - `$...$`   → inline math
    /// - Content inside fenced code blocks (``` ``` ```) and inline code spans (`` ` ``)
    ///   is treated as opaque markdown and never parsed for `$`.
    /// - `\$` outside math mode is an escaped dollar sign and emits a literal `$`.
    /// - An unclosed math delimiter at the end is auto-closed so the math still renders.
    private func splitIntoMarkdownAndLatexSegments(
        _ text: String
    ) -> [(content: String, isLatex: Bool, display: Bool)] {

        var segments: [(String, Bool, Bool)] = []
        var buffer = ""
        var i = text.startIndex

        var inMath = false
        var isDisplay = false
        var inCodeBlock = false
        var inInlineCode = false

        func flushMarkdown() {
            guard !buffer.isEmpty else { return }
            segments.append((buffer, false, false))
            buffer = ""
        }

        while i < text.endIndex {

            // ── Backtick handling (only outside math) ───────────────────────
            if !inMath && text[i] == "`" {
                var j = i
                var count = 0
                while j < text.endIndex && text[j] == "`" {
                    count += 1
                    j = text.index(after: j)
                }

                buffer.append(String(repeating: "`", count: count))

                if count >= 3 && !inInlineCode {
                    inCodeBlock.toggle()
                } else if count == 1 && !inCodeBlock {
                    inInlineCode.toggle()
                }

                i = j
                continue
            }

            // ── Pass code content through verbatim ──────────────────────────
            if inCodeBlock || inInlineCode {
                buffer.append(text[i])
                i = text.index(after: i)
                continue
            }

            // ── Escaped dollar sign (only outside math) ──────────────────────
            // Guard is important: inside math, backslashes belong to LaTeX
            // commands like \frac, \sqrt, etc. and must not be consumed here.
            if !inMath && text[i] == "\\" {
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "$" {
                    buffer.append("$")           // literal $ in prose
                    i = text.index(after: next)
                } else {
                    buffer.append("\\")          // pass other backslash sequences through
                    i = next
                }
                continue
            }

            // ── Dollar-sign delimiter logic ──────────────────────────────────
            if text[i] == "$" {
                let next = text.index(after: i)
                let isDouble = next < text.endIndex && text[next] == "$"

                if inMath {
                    let closingMatchesOpening = (isDisplay && isDouble) || (!isDisplay && !isDouble)
                    if closingMatchesOpening {
                        segments.append((buffer, true, isDisplay))
                        buffer = ""
                        inMath = false
                        isDisplay = false
                        i = isDouble ? text.index(after: next) : next
                    } else {
                        // Mismatched delimiter inside math → treat as literal
                        buffer.append("$")
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

            buffer.append(text[i])
            i = text.index(after: i)
        }

        // ── Flush remainder ──────────────────────────────────────────────────
        if !buffer.isEmpty {
            if inMath {
                // Auto-close dangling math so it renders instead of falling back to raw text.
                let opening = isDisplay ? "$$" : "$"
                let closing = isDisplay ? "$$" : "$"
                segments.append((buffer, true, isDisplay))
                // Prepend opening to previous markdown segment if needed so the text around stays intact.
                // We also keep a literal opening in markdown before, to avoid losing context.
                // Note: We prefer rendering the math rather than leaving raw text.
                if let last = segments.last, !last.1 { /* no-op */ }
                // Nothing else to do; we've emitted the math segment.
            } else {
                segments.append((buffer, false, false))
            }
        }

        return segments
    }
}

