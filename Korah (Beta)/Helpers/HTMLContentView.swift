import SwiftUI
import WebKit

// MARK: - College Board HTML renderer
// CB stem/paragraph/options/rationale are self-contained HTML (MathML, tables,
// SVG figures, absolute-URL <img>). A WKWebView renders them faithfully with
// the app's font/colors injected. Do NOT use the study markdown renderer here.

struct HTMLContentView: View {
    let html: String
    var fontSize: CGFloat = 17
    var textColorOverride: Color? = nil

    @State private var height: CGFloat = 24
    @State private var sized = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Fast path: simple markup (most stems, options, and prose passages)
        // renders as native text in the same frame — no WKWebView round-trip.
        if let attributed = SimpleHTMLRenderer.attributedString(
            html: html, fontSize: fontSize,
            textColor: textColorOverride ?? .kTextPrimary) {
            Text(attributed)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            SizingWebView(html: html,
                          fontSize: fontSize,
                          isDark: colorScheme == .dark,
                          height: $height,
                          sized: $sized)
                .frame(height: sized ? height : 48)
                .overlay(alignment: .topLeading) {
                    if !sized {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            SkeletonBox(height: 14)
                            SkeletonBox(height: 14).frame(width: 180)
                        }
                    }
                }
                .animation(.easeOut(duration: 0.15), value: sized)
        }
    }

    /// Spin up the WebContent process before the first question needs it so
    /// the initial MathML/figure render doesn't pay process-launch latency.
    static func warmUp() {
        SizingWebView.warmUp()
    }
}

private struct SizingWebView: UIViewRepresentable {
    let html: String
    let fontSize: CGFloat
    let isDark: Bool
    @Binding var height: CGFloat
    @Binding var sized: Bool

    // One shared web-content process for every sizing view; per-view pools
    // were paying process-launch cost (~1s) on each new question container.
    static let sharedProcessPool = WKProcessPool()

    private static var warmUpWebView: WKWebView?

    static func warmUp() {
        guard warmUpWebView == nil else { return }
        let config = WKWebViewConfiguration()
        config.processPool = sharedProcessPool
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
        warmUpWebView = webView
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = Self.sharedProcessPool
        config.userContentController.add(context.coordinator, name: "sizeChanged")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        // Content is read-only (links are already blocked below) — disabling
        // interaction lets taps pass through to a wrapping SwiftUI Button
        // instead of being captured by the web view's own gesture recognizers.
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let document = Self.wrap(html: html, fontSize: fontSize, isDark: isDark)
        guard document != context.coordinator.lastDocument else { return }
        context.coordinator.lastDocument = document
        webView.loadHTMLString(document, baseURL: URL(string: "https://saic.collegeboard.org"))
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "sizeChanged")
    }

    // Colors mirror korah.css --tx/--tx2/--p4 for each theme.
    static func wrap(html: String, fontSize: CGFloat, isDark: Bool) -> String {
        let text = isDark ? "#f0eaff" : "#1a0a3c"
        let secondary = isDark ? "#a89dc0" : "#5a4a7a"
        let accent = "#8b5cf6"
        let border = isDark ? "rgba(139,92,246,.25)" : "rgba(109,40,217,.2)"
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
        :root { color-scheme: \(isDark ? "dark" : "light"); }
        html, body { margin: 0; padding: 0; background: transparent; }
        body {
            font-family: -apple-system, 'Helvetica Neue', sans-serif;
            font-size: \(fontSize)px;
            line-height: 1.55;
            color: \(text);
            -webkit-text-size-adjust: none;
            overflow-wrap: break-word;
        }
        p { margin: 0.4em 0; }
        p:first-child { margin-top: 0; }
        p:last-child { margin-bottom: 0; }
        img, svg { max-width: 100%; height: auto; }
        figure { margin: 0.5em 0; }
        table { border-collapse: collapse; margin: 0.5em 0; max-width: 100%; }
        th, td { border: 1px solid \(border); padding: 0.35em 0.6em; font-size: 0.95em; }
        blockquote { margin: 0.5em 0; padding-left: 0.75em; border-left: 3px solid \(accent); color: \(secondary); }
        ul, ol { padding-left: 1.4em; margin: 0.4em 0; }
        a { color: \(accent); text-decoration: none; pointer-events: none; }
        math { font-size: 1.05em; }
        .sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0,0,0,0); }
        </style>
        </head>
        <body>\(html)
        <script>
        (function() {
            function report() {
                window.webkit.messageHandlers.sizeChanged.postMessage(document.body.scrollHeight);
            }
            window.addEventListener('load', report);
            new ResizeObserver(report).observe(document.body);
            report();
        })();
        </script>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: SizingWebView
        var lastDocument: String = ""

        init(_ parent: SizingWebView) { self.parent = parent }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "sizeChanged" else { return }
            let newHeight: CGFloat
            if let number = message.body as? NSNumber {
                newHeight = CGFloat(truncating: number)
            } else if let double = message.body as? Double {
                newHeight = CGFloat(double)
            } else {
                return
            }
            DispatchQueue.main.async { [self] in
                if abs(parent.height - newHeight) > 1 {
                    parent.height = max(newHeight, 1)
                }
                if !parent.sized { parent.sized = true }
            }
        }

        // Block link taps — content is read-only. Allow only the initial load.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - Native fast path for simple HTML

/// Converts plain-ish College Board HTML (prose with basic inline formatting)
/// straight into an AttributedString so SwiftUI draws it in the same frame,
/// with zero WKWebView latency. Returns nil for anything that needs the real
/// renderer — MathML, images, SVG, tables, or unrecognized markup — which
/// keeps this path strictly "instant or opt out", never "instant but wrong".
enum SimpleHTMLRenderer {

    private final class CachedResult {
        let value: AttributedString?
        init(_ value: AttributedString?) { self.value = value }
    }
    private static let cache = NSCache<NSString, CachedResult>()

    static func attributedString(html: String, fontSize: CGFloat, textColor: Color) -> AttributedString? {
        let key = "\(fontSize)|\(textColor)|\(html)" as NSString
        if let cached = cache.object(forKey: key) { return cached.value }
        let result = parse(html: html, fontSize: fontSize, textColor: textColor)
        cache.setObject(CachedResult(result), forKey: key)
        return result
    }

    // MARK: Parser

    private struct Style {
        var bold = false
        var italic = false
        var underline = false
        var strikethrough = false
        var script = 0        // +1 sup, -1 sub
        var hidden = false    // inside an sr-only span
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": "\u{00A0}", "ndash": "–", "mdash": "—", "shy": "",
        "lsquo": "\u{2018}", "rsquo": "\u{2019}", "ldquo": "\u{201C}", "rdquo": "\u{201D}",
        "hellip": "…", "minus": "−", "times": "×", "divide": "÷",
        "deg": "°", "plusmn": "±", "le": "≤", "ge": "≥", "ne": "≠",
        "pi": "π", "middot": "·", "bull": "•", "prime": "′", "Prime": "″",
        "frac12": "½", "frac14": "¼", "frac34": "¾", "cent": "¢", "sect": "§"
    ]

    private static func parse(html: String, fontSize: CGFloat, textColor: Color) -> AttributedString? {
        let chars = Array(html)
        var output = AttributedString()
        var styleStack: [Style] = [Style()]
        var textBuffer = ""
        var pendingBreaks = 0
        var lastWhitespace = true   // suppress leading/duplicate spaces
        var i = 0

        func flushText() {
            guard !textBuffer.isEmpty else { textBuffer = ""; return }
            let style = styleStack.last!
            defer { textBuffer = "" }
            guard !style.hidden else { return }
            var collapsed = ""
            for ch in textBuffer {
                if ch.isWhitespace && ch != "\u{00A0}" {
                    if !lastWhitespace { collapsed.append(" "); lastWhitespace = true }
                } else {
                    collapsed.append(ch)
                    lastWhitespace = false
                }
            }
            guard !collapsed.isEmpty else { return }
            if pendingBreaks > 0 {
                output += AttributedString(String(repeating: "\n", count: pendingBreaks))
                pendingBreaks = 0
            }
            var run = AttributedString(collapsed)
            var font = Font.system(size: style.script == 0 ? fontSize : fontSize * 0.75)
            if style.bold { font = font.bold() }
            if style.italic { font = font.italic() }
            run.font = font
            run.foregroundColor = textColor
            if style.underline { run.underlineStyle = .single }
            if style.strikethrough { run.strikethroughStyle = .single }
            if style.script != 0 { run.baselineOffset = CGFloat(style.script) * fontSize * 0.33 }
            output += run
        }

        func blockBreak() {
            flushText()
            guard !output.characters.isEmpty else { return }
            pendingBreaks = max(pendingBreaks, 1)
            lastWhitespace = true
        }

        func forcedBreak() {
            flushText()
            guard !output.characters.isEmpty else { return }
            pendingBreaks += 1
            lastWhitespace = true
        }

        while i < chars.count {
            let ch = chars[i]
            if ch == "<" {
                // Comments
                if i + 3 < chars.count, chars[i+1] == "!", chars[i+2] == "-", chars[i+3] == "-" {
                    var j = i + 4
                    while j + 2 < chars.count,
                          !(chars[j] == "-" && chars[j+1] == "-" && chars[j+2] == ">") { j += 1 }
                    guard j + 2 < chars.count else { return nil }
                    i = j + 3
                    continue
                }
                // Scan to the closing '>' (respecting quoted attribute values)
                var j = i + 1
                var quote: Character? = nil
                while j < chars.count {
                    let c = chars[j]
                    if let q = quote { if c == q { quote = nil } }
                    else if c == "\"" || c == "'" { quote = c }
                    else if c == ">" { break }
                    j += 1
                }
                guard j < chars.count else { return nil }
                let rawTag = String(chars[(i+1)..<j])
                i = j + 1

                let isClosing = rawTag.hasPrefix("/")
                let body = isClosing ? String(rawTag.dropFirst()) : rawTag
                let name = body.prefix { $0.isLetter || $0.isNumber }.lowercased()
                let lowered = rawTag.lowercased()
                // Anything visually non-trivial goes to the web view.
                if lowered.contains("display:none") { return nil }

                switch name {
                case "p", "div":
                    blockBreak()
                case "br":
                    forcedBreak()
                case "wbr":
                    break
                case "b", "strong", "i", "em", "u", "s", "del", "strike", "sup", "sub", "span":
                    if isClosing {
                        flushText()
                        if styleStack.count > 1 { styleStack.removeLast() }
                    } else {
                        flushText()
                        var style = styleStack.last!
                        switch name {
                        case "b", "strong": style.bold = true
                        case "i", "em": style.italic = true
                        case "u": style.underline = true
                        case "s", "del", "strike": style.strikethrough = true
                        case "sup": style.script = 1
                        case "sub": style.script = -1
                        case "span":
                            if lowered.contains("sr-only") { style.hidden = true }
                        default: break
                        }
                        styleStack.append(style)
                        // Self-closing (<span/> etc.) — pop right back.
                        if rawTag.hasSuffix("/") { styleStack.removeLast() }
                    }
                default:
                    // math, img, svg, table, ul/ol, figure, … → real renderer
                    return nil
                }
            } else if ch == "&" {
                // Decode the entity; unknown named entities bail to the web view.
                var j = i + 1
                var entity = ""
                while j < chars.count, chars[j] != ";", entity.count < 10 {
                    entity.append(chars[j]); j += 1
                }
                if j < chars.count, chars[j] == ";" {
                    if entity.hasPrefix("#") {
                        let digits = entity.dropFirst()
                        let scalarValue: UInt32?
                        if digits.hasPrefix("x") || digits.hasPrefix("X") {
                            scalarValue = UInt32(digits.dropFirst(), radix: 16)
                        } else {
                            scalarValue = UInt32(digits)
                        }
                        guard let value = scalarValue, let scalar = Unicode.Scalar(value) else { return nil }
                        textBuffer.append(Character(scalar))
                    } else if let replacement = namedEntities[entity] {
                        textBuffer.append(replacement)
                    } else {
                        return nil
                    }
                    i = j + 1
                } else {
                    textBuffer.append(ch)
                    i += 1
                }
            } else {
                textBuffer.append(ch)
                i += 1
            }
        }
        flushText()
        return output
    }
}
