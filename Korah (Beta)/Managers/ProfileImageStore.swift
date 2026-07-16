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

    private func fileURL(for userId: String) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("pfp_\(userId).jpg")
    }
}
