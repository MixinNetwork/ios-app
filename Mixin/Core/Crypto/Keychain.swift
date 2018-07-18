//
//  Keychain.swift
//  Mixin
//
//  Created by tangjun on 2018/7/17.
//  Copyright © 2018年 Mixin. All rights reserved.
//

import Foundation

//kSecClassGenericPassword

class Keychain {

    private let keyDeviceId = "device_id"
    private let authenticationService = "one.mixin.ios.authentication"

    static let shared = Keychain()

    func getPIN() -> String? {
        return nil
    }

    func setPIN(pin: String) {

    }

    func clearPIN() {

    }

    func getDeviceId() -> String {
        var deviceId = get(keyDeviceId) ?? ""
        if deviceId.isEmpty {
            deviceId = UUID().uuidString.lowercased()
            set(deviceId, key: keyDeviceId)
        }
        return deviceId
    }
    //SecItemDelete
    //

    private func get(_ key: String) -> String? {
        let query: [CFString: Any] = [kSecAttrService: authenticationService,
                                      kSecAttrAccount: key,
                                      kSecReturnData: kCFBooleanTrue,
                                      kSecMatchLimit: kSecMatchLimitOne,
                                      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func set(_ value: String, key: String) {
        guard let data = value.data(using: .utf8, allowLossyConversion: false) else {
            return
        }
        set(data, key: key)
    }

    private func remove(_ key: String) {

    }

    func set(_ value: Data, key: String, secret: Bool = false) {
//        var query: [CFString: Any] = [kSecAttrService: authenticationService,
//                                      kSecValueData: value,
//                                      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
//        if secret {
//            var error: NSError?
//            let sac = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, .touchIDAny, &error)
//            query[kSecClass] = kSecClassGenericPassword
//            query[kSecAttrAccessControl] = sac
//        }
//        SecItemCopyMatching(<#T##query: CFDictionary##CFDictionary#>, <#T##result: UnsafeMutablePointer<CFTypeRef?>?##UnsafeMutablePointer<CFTypeRef?>?#>)
//        switch SecItemCopyMatching(query as CFDictionary, nil) {
//        case errSecSuccess:
//            if SecItemUpdate(query as CFDictionary, nil) == errSecSuccess
//        case errSecItemNotFound:
//            SecItemAdd(query as CFDictionary, nil) == errSecSuccess
//        default:
//            break
//        }
    }

    subscript(key: String) -> String? {
        get {
            return get(key)
        }

        set {
            if let value = newValue {
                set(value, key: key)
            } else {
                remove(key)
            }
        }
    }

    public subscript(string key: String) -> String? {
        get {
            return self[key]
        }

        set {
            self[key] = newValue
        }
    }

}

extension Keychain {

    static func getDeviceId() -> String {
//        let keychain = Keychain(service: "one.mixin.ios.device")
//        var device_id = keychain["device_id"] ?? ""
//        if device_id.isEmpty {
//            device_id = UUID().uuidString.lowercased()
//            keychain["device_id"] = device_id
//        }
        return ""
    }


}

//import Foundation
//import KeychainAccess
//import UIKit
//
//extension Keychain {
//
//    private static let authenticationService = "one.mixin.ios.authentication"
//    private static let keyToken = "authentication_token"
//    private static let keyPinToken = "pin_token"
//
//    static func getDeviceId() -> String {
//        let keychain = Keychain(service: "one.mixin.ios.device")
//        var device_id = keychain["device_id"] ?? ""
//        if device_id.isEmpty {
//            device_id = UUID().uuidString.lowercased()
//            keychain["device_id"] = device_id
//        }
//        return device_id
//    }
//}

