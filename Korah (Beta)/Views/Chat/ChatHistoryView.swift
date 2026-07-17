import SwiftUI

// MARK: - Chat History

/// Minimal Claude-sidebar-style list of saved chats: each row shows the
/// AI-generated title, message count, and last-updated time. Reads the same
/// Firestore store `ChatViewModel` writes to.
struct ChatHistoryView: View {
    let onSelectConversation: (Conversation) -> Void
    let onDismiss: () -> Void

    @Environment(FirestoreConversationService.self) private var conversationService
    @State private var conversationToDelete: Conversation?

    private var conversations: [Conversation] { conversationService.conversations(ofType: .chat) }

    var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Color.kBackground)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                        .foregroundStyle(Color.kAccent)
                }
            }
        }
        .alert("Delete chat?", isPresented: Binding(
            get: { conversationToDelete != nil },
            set: { if !$0 { conversationToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let conversation = conversationToDelete {
                    Task { try? await conversationService.deleteConversation(id: conversation.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var list: some View {
        List {
            ForEach(conversations) { conversation in
                row(conversation)
                    .listRowBackground(Color.kBackground)
                    .listRowSeparatorTint(Color.kBorder)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectConversation(conversation)
                        onDismiss()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            conversationToDelete = conversation
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(_ conversation: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.kBody)
                .foregroundStyle(Color.kTextPrimary)
                .lineLimit(1)

            Text("\(conversation.messageCount) messages · \(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.kCaption)
                .foregroundStyle(Color.kTextSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(Color.kTextTertiary)
            Text("No chats yet")
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)
            Text("Your chat history will appear here.")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
