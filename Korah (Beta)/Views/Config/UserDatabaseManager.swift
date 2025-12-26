import Foundation

struct User: Codable {
    var firstName: String
    var username: String
    var email: String
    var password: String
}

struct UserDatabaseManager {
    static let key = "UserDatabase"
    
    static func saveUser(_ user: User) {
        var database = loadDatabase()
        database[user.email] = user
        if let data = try? JSONEncoder().encode(database) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    static func loadDatabase() -> [String: User] {
        if let data = UserDefaults.standard.data(forKey: key),
           let database = try? JSONDecoder().decode([String: User].self, from: data) {
            return database
        }
        return [:]
    }
    
    static func getUser(email: String) -> User? {
        return loadDatabase()[email]
    }
}
