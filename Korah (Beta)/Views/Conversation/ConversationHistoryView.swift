import SwiftUI

struct ConversationHistoryView: View {
    let type: ConversationType
    let onSelectConversation: (Conversation) -> Void
    let onDismiss: () -> Void
    
    @State private var conversations: [Conversation] = []
    @State private var showDeleteAlert = false
    @State private var conversationToDelete: Conversation?
    
    var body: some View {
        NavigationView {
            Group {
                if conversations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: type == .chat ? "bubble.left.and.bubble.right" : "doc.text.image")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No previous conversations")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                        Text("Your \(type == .chat ? "chat" : "scan") history will appear here")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            ConversationRow(conversation: conversation)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelectConversation(conversation)
                                    onDismiss()
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        conversationToDelete = conversation
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("\(type == .chat ? "Chat" : "Scan") History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .korahGradientBackground()
        .preferredColorScheme(.dark)
        .onAppear {
            loadConversations()
        }
        .alert("Delete Conversation", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let conversation = conversationToDelete {
                    deleteConversation(conversation)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this conversation?")
        }
    }
    
    private func loadConversations() {
        conversations = ConversationManager.shared.listConversations(type: type)
    }
    
    private func deleteConversation(_ conversation: Conversation) {
        try? ConversationManager.shared.deleteConversation(id: conversation.id, type: type)
        loadConversations()
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(conversation.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(conversation.updatedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(conversation.lastMessagePreview)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(2)
            
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                Text("\(conversation.messageCount) messages")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 4)
    }
}
