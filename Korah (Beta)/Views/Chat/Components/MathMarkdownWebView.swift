import SwiftUI
import WebKit

// MARK: - Math Markdown Web View

/// Renders assistant markdown + KaTeX math in a transparent, self-sizing
/// WKWebView using the exact same pipeline as the web app
/// (korah-chat.js renderMarkdownAndMath): normalize math delimiters →
/// marked.parse → DOMPurify.sanitize → KaTeX renderMathInElement.
///
/// Unlike the native segmentation approach, inline math like $x$ flows
/// within the surrounding sentence instead of breaking onto its own line.
struct MathMarkdownWebView: View {
    let content: String

    @State private var height: CGFloat = 22

    var body: some View {
        MathMarkdownWebViewRepresentable(content: content, height: $height)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - UIViewRepresentable

private struct MathMarkdownWebViewRepresentable: UIViewRepresentable {
    let content: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "contentHeight")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Real https base URL so the CDN scripts (marked, DOMPurify, KaTeX)
        // load from a secure origin, matching the web app's setup.
        webView.loadHTMLString(Self.template, baseURL: URL(string: APIConfig.baseURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.height = $height

        guard content != context.coordinator.lastContent else { return }
        context.coordinator.lastContent = content

        if context.coordinator.isLoaded {
            webView.evaluateJavaScript("window.setContent(\(Self.jsStringLiteral(content)));")
        } else {
            context.coordinator.pendingContent = content
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "contentHeight")
    }

    /// Encodes a Swift string as a JavaScript string literal (JSON is a
    /// subset of JS apart from U+2028/U+2029, which get escaped manually).
    private static func jsStringLiteral(_ string: String) -> String {
        let data = (try? JSONEncoder().encode(string)) ?? Data("\"\"".utf8)
        return String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var height: Binding<CGFloat>
        var isLoaded = false
        var lastContent: String?
        var pendingContent: String?

        init(height: Binding<CGFloat>) {
            self.height = height
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            if let pending = pendingContent {
                pendingContent = nil
                webView.evaluateJavaScript(
                    "window.setContent(\(MathMarkdownWebViewRepresentable.jsStringLiteral(pending)));"
                )
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Tapped links open in Safari; everything else (the template
            // load itself) proceeds in the web view.
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "contentHeight",
                  let newHeight = (message.body as? NSNumber).map({ CGFloat($0.doubleValue) }),
                  newHeight > 0,
                  abs(newHeight - height.wrappedValue) > 0.5 else { return }
            height.wrappedValue = newHeight
        }
    }

    // MARK: HTML Template

    /// Same libraries and versions as korah-web chat.html; the JS mirrors
    /// normalizeMathDelimiters + renderMarkdownAndMath from korah-chat.js.
    private static let template = #"""
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.10/dist/katex.min.css"/>
    <style>
      * { box-sizing: border-box; }
      html, body { margin: 0; padding: 0; background: transparent; }
      body {
        font-family: -apple-system, "SF Pro Text", sans-serif;
        font-size: 17px;
        line-height: 1.45;
        color: #1a0a3c;
        overflow-wrap: break-word;
        -webkit-text-size-adjust: 100%;
      }
      #content > :first-child { margin-top: 0; }
      #content > :last-child { margin-bottom: 0; }
      p { margin: 0 0 10px; }
      ul, ol { margin: 0 0 10px; padding-left: 24px; }
      li { margin: 2px 0 6px; }
      h1, h2, h3, h4 { margin: 14px 0 8px; line-height: 1.25; }
      h1 { font-size: 21px; }
      h2 { font-size: 19px; }
      h3 { font-size: 17px; }
      strong { font-weight: 600; }
      a { color: #7c3aed; }
      code {
        font-family: ui-monospace, "SF Mono", monospace;
        font-size: 15px;
        background: rgba(124, 58, 237, 0.08);
        padding: 1px 5px;
        border-radius: 5px;
      }
      pre {
        background: rgba(124, 58, 237, 0.08);
        padding: 10px 12px;
        border-radius: 10px;
        overflow-x: auto;
        margin: 0 0 10px;
      }
      pre code { background: none; padding: 0; }
      blockquote {
        margin: 0 0 10px;
        padding: 2px 0 2px 12px;
        border-left: 3px solid #7c3aed;
        color: #5a4a7a;
      }
      hr { border: none; border-top: 1px solid rgba(124, 58, 237, 0.18); margin: 12px 0; }
      table { border-collapse: collapse; margin: 0 0 10px; }
      th, td { border: 1px solid rgba(124, 58, 237, 0.18); padding: 4px 8px; }
      .katex { font-size: 1.06em; }
      .katex-display { overflow-x: auto; overflow-y: hidden; padding: 2px 0; margin: 8px 0 12px; }
      @media (prefers-color-scheme: dark) {
        body { color: #f0eaff; }
        a { color: #8b5cf6; }
        code, pre { background: rgba(139, 92, 246, 0.14); }
        blockquote { border-left-color: #8b5cf6; color: #a89dc0; }
        hr { border-top-color: rgba(139, 92, 246, 0.2); }
        th, td { border-color: rgba(139, 92, 246, 0.2); }
      }
    </style>
    </head>
    <body>
    <div id="content"></div>
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/dompurify@3/dist/purify.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/katex@0.16.10/dist/katex.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/katex@0.16.10/dist/contrib/auto-render.min.js"></script>
    <script>
      function postHeight() {
        window.webkit.messageHandlers.contentHeight.postMessage(document.documentElement.scrollHeight);
      }
      new ResizeObserver(postHeight).observe(document.body);

      function normalizeMathDelimiters(text) {
        return String(text || "")
          .split(/(```[\s\S]*?```)/g)
          .map(function (segment) {
            if (segment.startsWith("```")) return segment;

            return segment
              .replace(/`([^`]+)`/g, function (_, expr) {
                const trimmed = expr.trim();
                if (/[_^\\{}]/.test(trimmed)) {
                  return "$" + trimmed + "$";
                }
                return "`" + expr + "`";
              })
              .replace(/\\\((.*?)\\\)/gs, function (_, expr) {
                return "$" + expr.trim() + "$";
              })
              .replace(/\\[(.*?)]/gs, function (_, expr) {
                return "$$" + expr.trim() + "$$";
              })
              .replace(/([a-zA-Z])_([a-zA-Z0-9]+|\{[^}]+\})/g, "$1_{$2}");
          })
          .join("");
      }

      window.setContent = function (markdownText) {
        const el = document.getElementById("content");
        const normalized = normalizeMathDelimiters(markdownText || "");

        if (!window.marked || typeof marked.parse !== "function") {
          el.textContent = normalized;
          postHeight();
          return;
        }

        let html;
        try {
          html = marked.parse(normalized);
        } catch (e) {
          el.textContent = normalized;
          postHeight();
          return;
        }

        if (window.DOMPurify) {
          html = DOMPurify.sanitize(html, { USE_PROFILES: { html: true } });
        }
        el.innerHTML = html;

        if (window.renderMathInElement) {
          try {
            renderMathInElement(el, {
              delimiters: [
                { left: "$$", right: "$$", display: true },
                { left: "$", right: "$", display: false },
                { left: "\\(", right: "\\)", display: false }
              ],
              throwOnError: false
            });
          } catch (e) {}
        }
        postHeight();
      };
    </script>
    </body>
    </html>
    """#
}

// MARK: - Preview

#Preview {
    ScrollView {
        MathMarkdownWebView(content: """
        Solving for $x$ and $y$ first (e.g., $y = 6/x$, then substitute into $2x + 3y = 12$).

        $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$

        - **Practice Expansion:** Be quick with binomial expansion.
        - **Desmos as a Backup:** Check your work in Desmos.

        **Final Answer:** The value of $4x^2 + 9y^2$ is $\\boxed{72}$.
        """)
        .padding()
    }
    .kBackground()
}
