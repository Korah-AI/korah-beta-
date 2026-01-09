import Foundation

/// Manages a persistent device identifier for rate limiting and analytics
class DeviceIDManager {
    static let shared = DeviceIDManager()
    
    private let userDefaults = UserDefaults.standard
    private let deviceIDKey = "com.korah.deviceID"
    
    private init() {}
    
    /// Gets or creates a persistent device ID
    var deviceID: String {
        if let existingID = userDefaults.string(forKey: deviceIDKey) {
            return existingID
        }
        
        // Generate new UUID
        let newID = UUID().uuidString
        userDefaults.set(newID, forKey: deviceIDKey)
        return newID
    }
    
    /// Resets the device ID (useful for testing or user privacy requests)
    func resetDeviceID() {
        userDefaults.removeObject(forKey: deviceIDKey)
    }
}
