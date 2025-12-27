import Foundation
import UIKit

class ConversationManager {
    static let shared = ConversationManager()
    
    private let fileManager = FileManager.default
    private let conversationsDirectory: URL
    private let chatDirectory: URL
    private let scanDirectory: URL
    
    private init() {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        conversationsDirectory = documentsDirectory.appendingPathComponent("Conversations")
        chatDirectory = conversationsDirectory.appendingPathComponent("Chat")
        scanDirectory = conversationsDirectory.appendingPathComponent("Scan")
        
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        for directory in [conversationsDirectory, chatDirectory, scanDirectory] {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Save Conversation
    
    func saveConversation(_ conversation: Conversation) throws {
        let directory = conversation.type == .chat ? chatDirectory : scanDirectory
        let fileURL = directory.appendingPathComponent("\(conversation.id.uuidString).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(conversation)
        try data.write(to: fileURL)
    }
    
    // MARK: - Load Conversation
    
    func loadConversation(id: UUID, type: ConversationType) throws -> Conversation {
        let directory = type == .chat ? chatDirectory : scanDirectory
        let fileURL = directory.appendingPathComponent("\(id.uuidString).json")
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Conversation.self, from: data)
    }
    
    // MARK: - List Conversations
    
    func listConversations(type: ConversationType) -> [Conversation] {
        let directory = type == .chat ? chatDirectory : scanDirectory
        
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else {
            return []
        }
        
        let conversations = fileURLs.compactMap { fileURL -> Conversation? in
            guard fileURL.pathExtension == "json" else { return nil }
            return try? loadConversationFromURL(fileURL)
        }
        
        return conversations.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    private func loadConversationFromURL(_ url: URL) throws -> Conversation {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Conversation.self, from: data)
    }
    
    // MARK: - Delete Conversation
    
    func deleteConversation(id: UUID, type: ConversationType) throws {
        let directory = type == .chat ? chatDirectory : scanDirectory
        let fileURL = directory.appendingPathComponent("\(id.uuidString).json")
        
        // Delete images directory if it exists (for scan conversations)
        if type == .scan {
            let imagesDirectory = scanDirectory.appendingPathComponent("\(id.uuidString)_images")
            if fileManager.fileExists(atPath: imagesDirectory.path) {
                try fileManager.removeItem(at: imagesDirectory)
            }
        }
        
        // Delete conversation file
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    // MARK: - Image Management (for Scan Conversations)
    
    func saveImage(_ image: UIImage, forConversation conversationId: UUID, messageId: UUID) -> String? {
        let imagesDirectory = scanDirectory.appendingPathComponent("\(conversationId.uuidString)_images")
        
        if !fileManager.fileExists(atPath: imagesDirectory.path) {
            try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
        
        let fileName = "\(messageId.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        do {
            try imageData.write(to: fileURL)
            return fileName
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    func loadImage(fileName: String, forConversation conversationId: UUID) -> UIImage? {
        let imagesDirectory = scanDirectory.appendingPathComponent("\(conversationId.uuidString)_images")
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        
        guard let imageData = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: imageData)
    }
    
    // MARK: - Auto-save Helper
    
    func autoSaveConversation(_ conversation: Conversation) {
        DispatchQueue.global(qos: .background).async {
            try? self.saveConversation(conversation)
        }
    }
    
    // MARK: - Generate Title Helper
    
    func generateTitle(from firstMessage: String) -> String {
        var cleaned = firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove JSON-like content (anything between curly braces)
        if let openBrace = cleaned.firstIndex(of: "{"),
           let closeBrace = cleaned.lastIndex(of: "}") {
            if openBrace < closeBrace {
                cleaned.removeSubrange(openBrace...closeBrace)
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove markdown and special formatting
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        cleaned = cleaned.replacingOccurrences(of: "##", with: "")
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.isEmpty {
            return "New Conversation"
        }
        
        let maxLength = 40
        if cleaned.count <= maxLength {
            return cleaned
        }
        
        return String(cleaned.prefix(maxLength)) + "..."
    }
}
