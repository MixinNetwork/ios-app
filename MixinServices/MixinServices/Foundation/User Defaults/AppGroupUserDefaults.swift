import Foundation

public enum AppGroupUserDefaults {
    
    internal static let defaults = UserDefaults(suiteName: appGroupIdentifier)!
    
    public enum Namespace {
        case signal
        case crypto
        case account
        case user
        case database
        case wallet
        
        var stringValue: String {
            if self == .signal {
                return "signal"
            } else if self == .crypto {
                return "crypto"
            } else if self == .account {
                return "account"
            } else if self == .user {
                return "user." + myIdentityNumber
            } else if self == .database {
                return "database." + myIdentityNumber
            } else if self == .wallet {
                return "wallet." + myIdentityNumber
            }
            fatalError("Unhandled namespace")
        }
    }
    
    @propertyWrapper
    public class Default<Value> {
        
        fileprivate let namespace: Namespace?
        fileprivate let key: String
        fileprivate let defaultValue: Value
        
        fileprivate var wrappedKey: String {
            Self.wrappedKey(forNamespace: namespace, key: key)
        }
        
        // default values are returned as is without writting back
        public init(namespace: Namespace?, key: String, defaultValue: Value) {
            self.namespace = namespace
            self.key = key
            self.defaultValue = defaultValue
        }
        
        // default values are returned as is without writting back
        public convenience init<KeyType: RawRepresentable>(namespace: Namespace?, key: KeyType, defaultValue: Value) where KeyType.RawValue == String {
            self.init(namespace: namespace, key: key.rawValue, defaultValue: defaultValue)
        }
        
        public var wrappedValue: Value {
            get {
                defaults.object(forKey: wrappedKey) as? Value ?? defaultValue
            }
            set {
                if let newValue = newValue as? AnyOptional, newValue.isNil {
                    defaults.removeObject(forKey: wrappedKey)
                } else {
                    defaults.set(newValue, forKey: wrappedKey)
                }
            }
        }
        
        static func wrappedKey(forNamespace namespace: Namespace?, key: String) -> String {
            if let namespace = namespace {
                return namespace.stringValue + "." + key
            } else {
                return key
            }
        }
        
    }
    
    @propertyWrapper
    public class RawRepresentableDefault<Value: RawRepresentable>: Default<Value> where Value.RawValue: PropertyListType {
        
        public override var wrappedValue: Value {
            get {
                if let rawValue = defaults.object(forKey: wrappedKey) as? Value.RawValue, let value = Value(rawValue: rawValue) {
                    return value
                } else {
                    return defaultValue
                }
            }
            set {
                defaults.set(newValue.rawValue, forKey: wrappedKey)
            }
        }
        
    }
    
}

extension AppGroupUserDefaults {
    
    @Default(namespace: nil, key: "first_launch_date", defaultValue: nil)
    public static var firstLaunchDate: Date?
    
    @Default(namespace: nil, key: "currency_rates", defaultValue: [:])
    public static var currencyRates: [String: Double]
    
    @Default(namespace: nil, key: "server_index", defaultValue: 0)
    public static var serverIndex: Int
    
    @Default(namespace: nil, key: "documents_migrated", defaultValue: false)
    public static var isDocumentsMigrated: Bool
    
    @Default(namespace: nil, key: "is_running_in_main_app", defaultValue: false)
    public static var isRunningInMainApp: Bool

    @Default(namespace: nil, key: "processing_messages_in_extension", defaultValue: false)
    public static var isProcessingMessagesInAppExtension: Bool {
        didSet {
            AppGroupUserDefaults.checkStatusTimeInAppExtension = Date()
        }
    }
    
    @Default(namespace: nil, key: "check_status_in_app_extension", defaultValue: Date())
    public static var checkStatusTimeInAppExtension: Date

    @Default(namespace: nil, key: "notification_bulletin_dismissal_date", defaultValue: nil)
    public static var notificationBulletinDismissalDate: Date?
    
}

extension AppGroupUserDefaults {
    
    public static func migrateIfNeeded() {
        guard needsMigration else {
            return
        }
        let interval = CommonUserDefault.shared.firstLaunchTimeIntervalSince1970
        if interval != 0 {
            // A 0 interval indicates this value has never been written
            // Just leave it to AppDelegate
            firstLaunchDate = Date(timeIntervalSince1970: interval)
        }
        Account.migrate()
        User.migrate()
        Signal.migrate()
        Crypto.migrate()
        Database.migrate()
        Wallet.migrate()
        AccountUserDefault.shared.clear()
    }
    
    public static func migrateUserSpecificDefaults() {
        User.migrate()
        Database.migrate()
        Wallet.migrate()
    }
    
    private static var needsMigration: Bool {
        let old = AccountUserDefault.shared.serializedAccount
        let new = AppGroupUserDefaults.Account.serializedAccount
        return old != nil && new == nil
    }
    
}
