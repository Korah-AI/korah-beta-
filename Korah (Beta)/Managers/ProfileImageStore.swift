import SwiftUI
import UIKit

/// Keeps the user's custom profile picture on-device only — saved to the
/// app's Documents directory, keyed by user id. No network/Firebase Storage.
@MainActor
@Observable
final class ProfileImageStore {
    static let shared = ProfileImageStore()

    private(set) var image: UIImage?
    private var loadedUserId: String?

    private init() {}

    func load(for userId: String) {
        guard loadedUserId != userId else { return }
        loadedUserId = userId
        image = UIImage(contentsOfFile: fileURL(for: userId).path)
    }

    func save(_ image: UIImage, for userId: String) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: fileURL(for: userId), options: .atomic)
        loadedUserId = userId
        self.image = image
    }

    /// Removes the saved photo from disk. Used by account deletion so a
    /// re-signup on the same device never inherits the old avatar.
    func delete(for userId: String) {
        try? FileManager.default.removeItem(at: fileURL(for: userId))
        if loadedUserId == userId {
            loadedUserId = nil
            image = nil
        }
    }

    private func fileURL(for userId: String) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("pfp_\(userId).jpg")
    }
}
