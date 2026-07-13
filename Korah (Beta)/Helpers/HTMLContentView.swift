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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SizingWebView(html: html,
                      fontSize: fontSize,
                      isDark: colorScheme == .dark,
                      height: $height)
            .frame(height: height)
    }
}

private struct SizingWebView: UIViewRepresentable {
    let html: String
    let fontSize: CGFloat
    let isDark: Bool
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "sizeChanged")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
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
            if abs(parent.height - newHeight) > 1 {
                DispatchQueue.main.async { [self] in
                    parent.height = max(newHeight, 1)
                }
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
