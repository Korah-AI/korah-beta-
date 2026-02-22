import SwiftUI
import MarkdownUI
import LaTeXSwiftUI

/// A markdown view that renders LaTeX math equations
struct LatexMarkdownView: View {
    let content: String
    let isStreaming: Bool
    
    var body: some View {
        if isStreaming {
            Markdown(content)
                .markdownTheme(.korah)
        } else {
            renderMarkdownWithLatexSegments(content)
        }
    }
    
    @ViewBuilder
    private func renderMarkdownWithLatexSegments(_ text: String) -> some View {
        let segments = splitIntoMarkdownAndLatexSegments(text)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                if segment.isLatex {
                    let latexSource = segment.content
                    LaTeX(latexSource)
                        .parsingMode(.onlyEquations)
                        .font(.system(size: 17))
                        .foregroundColor(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                } else if !segment.content.isEmpty {
                    Markdown(segment.content)
                        .markdownTheme(.korah)
                }
            }
        }
    }
    
    private func splitIntoMarkdownAndLatexSegments(_ text: String) -> [(content: String, isLatex: Bool, display: Bool)] {
        var segments: [(String, Bool, Bool)] = []
        var buffer = ""
        var i = text.startIndex
        var inMath = false
        var isDisplay = false
        var inCodeBlock = false
        var inInlineCode = false

        func flushMarkdown() {
            if !buffer.isEmpty {
                segments.append((buffer, false, false))
                buffer = ""
            }
        }

        while i < text.endIndex {
            // Handle code fences and inline code toggling when NOT in math
            if !inMath {
                // Detect backtick runs
                if text[i] == "`" {
                    var j = i
                    var count = 0
                    while j < text.endIndex && text[j] == "`" {
                        count += 1
                        j = text.index(after: j)
                    }

                    if count >= 3 && !inInlineCode {
                        // Toggle fenced code block
                        // Preserve backticks in markdown buffer
                        buffer.append(String(repeating: "`", count: count))
                        inCodeBlock.toggle()
                        i = j
                        continue
                    } else if count == 1 && !inCodeBlock {
                        // Toggle inline code
                        buffer.append("`")
                        inInlineCode.toggle()
                        i = j
                        continue
                    } else {
                        // Just append the backticks as literal
                        buffer.append(String(repeating: "`", count: count))
                        i = j
                        continue
                    }
                }
            }

            // If inside code (block or inline), treat everything literally
            if inCodeBlock || inInlineCode {
                buffer.append(text[i])
                i = text.index(after: i)
                continue
            }

            // Support escaping of dollar sign: \$
            if text[i] == "\\" {
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "$" {
                    buffer.append("$")
                    i = text.index(after: next)
                    continue
                } else {
                    buffer.append("\\")
                    i = next
                    continue
                }
            }

            let ch = text[i]
            if ch == "$" {
                let next = text.index(after: i)
                let isDouble = next < text.endIndex && text[next] == "$"

                if inMath {
                    // Closing delimiter must match opening kind
                    if (isDisplay && isDouble) || (!isDisplay && !isDouble) {
                        // Flush LaTeX buffer (we do not include delimiters)
                        segments.append((buffer, true, isDisplay))
                        buffer = ""
                        inMath = false
                        isDisplay = false
                        i = isDouble ? text.index(after: next) : next
                        continue
                    } else {
                        // Mismatched: treat as literal '$'
                        buffer.append("$")
                        i = next
                        continue
                    }
                } else {
                    // Starting a math segment, flush markdown buffer first
                    flushMarkdown()
                    inMath = true
                    isDisplay = isDouble
                    i = isDouble ? text.index(after: next) : next
                    continue
                }
            }

            buffer.append(ch)
            i = text.index(after: i)
        }

        // Flush remainder. If still in math, treat as markdown (unclosed math)
        if !buffer.isEmpty {
            if inMath {
                // Put the opening delimiter back to keep the text intact as markdown
                let opening = isDisplay ? "$$" : "$"
                segments.append((opening + buffer, false, false))
            } else {
                segments.append((buffer, false, false))
            }
        }

        return segments
    }
}

