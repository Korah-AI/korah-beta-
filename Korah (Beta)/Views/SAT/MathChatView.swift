import SwiftUI

// MARK: - Desmos Chat (Math Chat)
// AI chat that renders interactive graphs: streams from /api/r and parses
// ```desmos fenced blocks (one Desmos expression per line) into the embedded
// Desmos calculator. Text renders as Markdown + KaTeX.

struct MathChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String        // "user" | "assistant"
    var text: String        // display text (desmos blocks stripped)
    var raw: String = ""    // full model output (kept for history context)
    var isStreaming = false
}

@MainActor
@Observable
final class MathChatModel {
    var messages: [MathChatMessage] = []
    var input = ""
    var expressions: [String] = []
    var isStreaming = false
    var errorMessage: String?

    private var streamTask: Task<Void, Never>?

    private static let systemPrompt = """
    You are Korah, an SAT Math tutor with an interactive Desmos graphing calculator on screen.

    GRAPHS: When a visual helps (linear systems, parabolas, inequalities, scatterplots, circles), include ONE fenced block of Desmos expressions, one expression per line, using Desmos-compatible latex/plain syntax:

    ```desmos
    y = 2x + 3
    y = x^2 - 4
    ```

    Rules for the desmos block:
    - Plain calculator syntax (y = 2x + 3, x^2 + y^2 = 25, y < 3x). No \\( \\) delimiters inside the block.
    - At most one block per reply. Omit it when a graph adds nothing.

    TEXT: Everything else is Markdown + KaTeX ($inline$ or $$display$$ math — every variable and equation in math delimiters). Be concise and confident: a few tight sentences or short steps, state the key move and the result, land on a clear final answer. Vary your openings. When you included a graph, reference what it shows.
    """

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        input = ""
        errorMessage = nil
        messages.append(MathChatMessage(role: "user", text: text, raw: text))
        Haptics.light()

        var assistant = MathChatMessage(role: "assistant", text: "", isStreaming: true)
        let assistantId = assistant.id
        messages.append(assistant)
        isStreaming = true

        // History for the API (raw text so the model sees its own desmos blocks)
        var apiMessages: [AIChatMessage] = [AIChatMessage(role: "system", content: Self.systemPrompt)]
        for message in messages where message.id != assistantId {
            apiMessages.append(AIChatMessage(role: message.role, content: message.raw))
        }

        streamTask = Task {
            do {
                let full = try await KorahAIClient.shared.stream(
                    messages: apiMessages, temperature: 0.3
                ) { [weak self] _, accumulated in
                    Task { @MainActor [weak self] in
                        self?.updateAssistant(id: assistantId, raw: accumulated, streaming: true)
                    }
                }
                updateAssistant(id: assistantId, raw: full, streaming: false)
            } catch {
                if let index = messages.firstIndex(where: { $0.id == assistantId }) {
                    if messages[index].text.isEmpty {
                        messages.remove(at: index)
                    } else {
                        messages[index].isStreaming = false
                    }
                }
                errorMessage = error.localizedDescription
            }
            isStreaming = false
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let index = messages.lastIndex(where: { $0.role == "assistant" }) {
            messages[index].isStreaming = false
        }
    }

    func clear() {
        stop()
        messages.removeAll()
        expressions = []
        errorMessage = nil
    }

    private func updateAssistant(id: UUID, raw: String, streaming: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        let parsed = Self.parseDesmos(from: raw, includePartial: !streaming)
        messages[index].raw = raw
        messages[index].text = parsed.text
        messages[index].isStreaming = streaming
        if !parsed.expressions.isEmpty {
            expressions = parsed.expressions
        }
    }

    /// Extracts ```desmos blocks. While streaming, an unterminated block is
    /// hidden from the display text but not yet pushed to the calculator.
    static func parseDesmos(from raw: String, includePartial: Bool) -> (text: String, expressions: [String]) {
        var text = ""
        var expressions: [String] = []
        var remainder = Substring(raw)

        while let openRange = remainder.range(of: "```desmos") {
            text += remainder[..<openRange.lowerBound]
            let afterOpen = remainder[openRange.upperBound...]
            if let closeRange = afterOpen.range(of: "```") {
                let block = afterOpen[..<closeRange.lowerBound]
                expressions.append(contentsOf: block
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty })
                remainder = afterOpen[closeRange.upperBound...]
            } else {
                // Unterminated block (still streaming) — swallow it
                if includePartial {
                    expressions.append(contentsOf: afterOpen
                        .split(separator: "\n")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty })
                }
                remainder = Substring("")
            }
        }
        text += remainder
        return (text.trimmingCharacters(in: .whitespacesAndNewlines), expressions)
    }
}

struct MathChatView: View {
    @State private var model = MathChatModel()
    @State private var graphExpanded = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Desmos panel (collapsible)
            if !model.expressions.isEmpty || graphExpanded {
                DesmosWebView(expressions: model.expressions)
                    .frame(height: graphExpanded ? 380 : 230)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .stroke(Color.kBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                        if model.messages.isEmpty {
                            welcome
                        }
                        ForEach(model.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                        if let error = model.errorMessage {
                            Text(error)
                                .font(.kCaption)
                                .foregroundStyle(Color.kError)
                                .padding(.horizontal, Spacing.md)
                        }
                    }
                    .padding(.vertical, Spacing.sm)
                }
                .onChange(of: model.messages.last?.text) {
                    if let last = model.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            composer
        }
        .background(Color.kBackground)
        .navigationTitle("Desmos Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(KAnimation.standard) { graphExpanded.toggle() }
                } label: {
                    Image(systemName: graphExpanded ? "rectangle.compress.vertical" : "chart.xyaxis.line")
                }
                Button {
                    model.clear()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(model.messages.isEmpty)
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: Spacing.sm) {
            Image("desmosdemo")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                .opacity(0.9)
            Text("Math help with live graphs")
                .font(.kTitle3)
                .foregroundStyle(Color.kTextPrimary)
            Text("Ask any SAT math question — Korah explains it and graphs it on the Desmos calculator above.")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: Spacing.xs) {
                suggestionButton("Graph y = 2x + 3 and explain slope")
                suggestionButton("Solve the system y = x² and y = x + 2")
                suggestionButton("How do I find a circle's center from its equation?")
            }
            .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
    }

    private func suggestionButton(_ text: String) -> some View {
        Button {
            model.input = text
            model.send()
        } label: {
            Text(text)
                .font(.kCaption)
                .foregroundStyle(Color.kAccent)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(Color.kAccent.opacity(0.08)))
                .overlay(Capsule().stroke(Color.kAccent.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func messageBubble(_ message: MathChatMessage) -> some View {
        if message.role == "user" {
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(.kBody)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.bubble, style: .continuous)
                            .fill(LinearGradient.kPurpleGradient)
                    )
            }
            .padding(.horizontal, Spacing.md)
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if message.text.isEmpty && message.isStreaming {
                        ProgressView().tint(Color.kAccent)
                    } else {
                        LatexMarkdownView(content: message.text, isStreaming: message.isStreaming)
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .kGlassEffect(cornerRadius: CornerRadius.bubble)
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private var composer: some View {
        HStack(spacing: Spacing.xs) {
            TextField("Ask a math question…", text: $model.input, axis: .vertical)
                .font(.kBody)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.kSurface))
                .overlay(Capsule().stroke(Color.kBorder, lineWidth: 1))
                .onSubmit { model.send() }

            Button {
                if model.isStreaming {
                    model.stop()
                } else {
                    model.send()
                    inputFocused = false
                }
            } label: {
                Image(systemName: model.isStreaming ? "stop.fill" : "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(LinearGradient.kPurpleGradient))
            }
            .disabled(!model.isStreaming && model.input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }
}
