import SwiftUI
import WebKit

// MARK: - Desmos graphing calculator embed
// No native SDK exists — the web app embeds the Desmos JS API, and we do the
// same in a WKWebView. `expressions` are Desmos latex strings pushed via
// setExpression as they change (used by Math Chat's ```desmos blocks).

struct DesmosWebView: UIViewRepresentable {
    /// Desmos expressions (latex strings) to plot. Empty = blank calculator.
    var expressions: [String] = []

    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.loadHTMLString(Self.page(isDark: colorScheme == .dark), baseURL: URL(string: "https://www.desmos.com"))
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        guard coordinator.lastExpressions != expressions else { return }
        coordinator.lastExpressions = expressions
        coordinator.pushExpressions(expressions)
    }

    static func page(isDark: Bool) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
        html, body { margin: 0; padding: 0; height: 100%; background: transparent; }
        #calculator { width: 100%; height: 100%; }
        </style>
        </head>
        <body>
        <div id="calculator"></div>
        <script src="https://www.desmos.com/api/v1.9/calculator.js?apiKey=dcb31709b452b1cf9dc26972add0fda6"></script>
        <script>
        var elt = document.getElementById('calculator');
        window.calculator = Desmos.GraphingCalculator(elt, {
            keypad: true,
            expressions: true,
            settingsMenu: false,
            zoomButtons: true,
            expressionsTopbar: true,
            pointsOfInterest: true,
            trace: true,
            border: false,
            lockViewport: false,
            invertedColors: \(isDark ? "true" : "false")
        });
        window.setKorahExpressions = function(list) {
            try {
                window.calculator.setBlank();
                list.forEach(function(latex, i) {
                    window.calculator.setExpression({ id: 'korah-' + i, latex: latex });
                });
            } catch (e) { /* ignore malformed expressions */ }
        };
        </script>
        </body>
        </html>
        """
    }

    final class Coordinator {
        weak var webView: WKWebView?
        var lastExpressions: [String] = []

        func pushExpressions(_ expressions: [String]) {
            guard let webView else { return }
            guard let data = try? JSONSerialization.data(withJSONObject: expressions),
                  let json = String(data: data, encoding: .utf8) else { return }
            let js = "window.setKorahExpressions && window.setKorahExpressions(\(json));"
            // Retry shortly if the calculator hasn't finished booting.
            webView.evaluateJavaScript(js) { _, error in
                if error != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        webView.evaluateJavaScript(js, completionHandler: nil)
                    }
                }
            }
        }
    }
}

/// Full-screen calculator sheet used by the player and rush.
struct DesmosCalculatorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DesmosWebView()
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Calculator")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
