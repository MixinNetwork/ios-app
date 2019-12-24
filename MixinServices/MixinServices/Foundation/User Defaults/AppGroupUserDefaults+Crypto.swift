import Foundation

extension AppGroupUserDefaults {
    
    public enum Crypto {
        
        enum Key: String, CaseIterable {
            case statusOffset = "status_offset"
            case prekeyOffset = "prekey_offset"
            case signedPrekeyOffset = "signed_prekey_offset"
            case isPrekeyLoaded = "prekey_loaded"
            case isSessionSynchronized = "session_synchronized"
            case oneTimePrekeyRefreshDate = "one_time_prekey_refresh_date"
            case iterator = "iterator"
        }
        
        public enum Offset {
            
            @Default(namespace: .crypto, key: Key.statusOffset, defaultValue: AppGroupUserDefaults.User.lastUpdateOrInstallDate.nanosecond())
            public static var status: Int64
            
            @Default(namespace: .crypto, key: Key.prekeyOffset, defaultValue: nil)
            public static var prekey: UInt32?
            
            @Default(namespace: .crypto, key: Key.signedPrekeyOffset, defaultValue: nil)
            public static var signedPrekey: UInt32?
            
        }
        
        @Default(namespace: .crypto, key: Key.isPrekeyLoaded, defaultValue: false)
        public static var isPrekeyLoaded: Bool
        
        @Default(namespace: .crypto, key: Key.isSessionSynchronized, defaultValue: false)
        public static var isSessionSynchronized: Bool
        
        @Default(namespace: .crypto, key: Key.oneTimePrekeyRefreshDate, defaultValue: nil)
        public static var oneTimePrekeyRefreshDate: Date?
        
        @Default(namespace: .crypto, key: Key.iterator, defaultValue: 1)
        public static var iterator: UInt64
        
        public static func clearAll() {
            Key.allCases
                .map({ $0.rawValue })
                .forEach(defaults.removeObject(forKey:))
            defaults.synchronize()
        }
        
        internal static func migrate() {
            Offset.status = CryptoUserDefault.shared.statusOffset
            Offset.prekey = CryptoUserDefault.shared.prekeyOffset
            Offset.signedPrekey = CryptoUserDefault.shared.signedPrekeyOffset
            isPrekeyLoaded = CryptoUserDefault.shared.isLoaded
            isSessionSynchronized = CryptoUserDefault.shared.isSyncSession
            oneTimePrekeyRefreshDate = Date(timeIntervalSince1970: CryptoUserDefault.shared.refreshOneTimePreKey)
            iterator = CryptoUserDefault.shared.iterator
        }
        
    }
    
}
