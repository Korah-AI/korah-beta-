import Foundation

extension URLRequest {
    /// Adds the device ID header for rate limiting
    mutating func addDeviceIDHeader() {
        let deviceID = DeviceIDManager.shared.deviceID
        self.addValue(deviceID, forHTTPHeaderField: "X-Device-ID")
    }
}
