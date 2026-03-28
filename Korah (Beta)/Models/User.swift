import Foundation

struct User: Codable, Identifiable {
    let id: String
    let username: String
    let firstName: String
    var lastName: String?
    /// The user's real email address. Optional — not required for sign-up.
    /// Stored privately in `users/{uid}`; never written to public collections.
    var email: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case firstName
        case lastName
        case email
        case createdAt
    }

    init(
        id: String,
        username: String,
        firstName: String,
        lastName: String? = nil,
        email: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.createdAt = createdAt
    }
}
