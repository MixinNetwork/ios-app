import Foundation

public enum AppGroupKeychain {
    
    private enum Tag {
        static let deviceID = Data([0x00]) as NSData
        static let sessionSecret = Data([0x01]) as NSData
        static let pinToken = Data([0x02]) as NSData
        static let ephemeralSeed = Data([0x03]) as NSData
        static let tipPriv = Data([0x04]) as NSData
        static let salt = Data([0x05]) as NSData
        static let mnemonics = Data([0x06]) as NSData
    }
    
    @Item(query: [kSecClass: kSecClassKey, kSecAttrApplicationTag: Tag.deviceID])
    public static var deviceID: Data?
    
    @Item(query: [kSecClass: kSecClassKey, kSecAttrApplicationTag: Tag.sessionSecret])
    public static var sessionSecret: Data?
    
    @Item(query: [kSecClass: kSecClassKey, kSecAttrApplicationTag: Tag.pinToken])
    public static var pinToken: Data?
    
    @Item(query: [kSecClass: kSecClassKey, kSecAttrApplicationTag: Tag.ephemeralSeed])
    public static var ephemeralSeed: Data?
    
    @Item(query: [kSecClass: kSecClassKey, kSecAttrApplicationTag: Tag.tipPriv])
    public static var encryptedTIPPriv: Data?
    
    @Item(query: [kSecClass: kSecClassKey, kSecAttrApplicationTag: Tag.salt])
    public static var encryptedSalt: Data?
    
    @Item(query: [kSecClass: kSecClassKey, kSecAttrApplicationTag: Tag.mnemonics])
    public static var mnemonics: Data?
    
    public static func removeItemsForCurrentSession() {
        sessionSecret = nil
        pinToken = nil
        ephemeralSeed = nil
        encryptedTIPPriv = nil
        encryptedSalt = nil
        mnemonics = nil
    }
    
}

extension AppGroupKeychain {
    
    @propertyWrapper
    public class Item {
        
        fileprivate typealias Query = [AnyHashable: Any]
        
        fileprivate let query: Query
        
        fileprivate init(query: Query) {
            var mutableQuery = query
            mutableQuery[kSecAttrAccessGroup] = appGroupIdentifier as NSString
            self.query = mutableQuery
        }
        
        public var wrappedValue: Data? {
            get {
                var query = self.query
                query[kSecReturnData] = kCFBooleanTrue
                query[kSecMatchLimit] = kSecMatchLimitOne
                var value: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &value)
                if status == errSecSuccess, let data = value as? Data {
                    return data
                } else {
                    return nil
                }
            }
            set {
                let isItemExisted = self.wrappedValue != nil
                if let newValue = newValue {
                    var query = self.query
                    query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                    let status: OSStatus
                    if isItemExisted {
                        let attributes = [kSecValueData: newValue]
                        status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
                    } else {
                        query[kSecValueData] = newValue
                        status = SecItemAdd(query as CFDictionary, nil)
                    }
                } else if isItemExisted {
                    SecItemDelete(query as CFDictionary)
                }
            }
        }
        
    }
    
}
