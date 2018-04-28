import Foundation
import KeychainAccess
import UIKit

extension Keychain {

    private static let authenticationService = "one.mixin.ios.authentication"
    private static let keyToken = "authentication_token"
    private static let keyPinToken = "pin_token"

    static func getDeviceId() -> String {
        let keychain = Keychain(service: "one.mixin.ios.device")
        var device_id = keychain["device_id"] ?? ""
        if device_id.isEmpty {
            device_id = UUID().uuidString.lowercased()
            keychain["device_id"] = device_id
        }
        return device_id
    }

    static func getToken() -> String? {
        return Keychain(service: Keychain.authenticationService)[keyToken]
    }

    static func getPinToken() -> String? {
        return Keychain(service: Keychain.authenticationService)[keyPinToken]
    }

    static func removeToken() {
        Keychain(service: Keychain.authenticationService)[keyToken] = nil
    }

    static func removePinToken() {
        Keychain(service: Keychain.authenticationService)[keyPinToken] = nil
    }
}
