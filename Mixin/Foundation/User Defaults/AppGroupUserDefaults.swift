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
            switch self {
            case .signal:
                return "signal"
            case .crypto:
                return "crypto"
            case .account:
                return "account"
            case .user:
                return "user." + AccountAPI.shared.accountIdentityNumber
            case .database:
                return "database." + AccountAPI.shared.accountIdentityNumber
            case .wallet:
                return "wallet." + AccountAPI.shared.accountIdentityNumber
            }
        }
    }
    
    @propertyWrapper
    public class Default<Value> {
        
        fileprivate let namespace: Namespace?
        fileprivate let key: String
        fileprivate let defaultValue: Value
        
        fileprivate var wrappedKey: String {
            if let namespace = namespace {
                return namespace.stringValue + "." + key
            } else {
                return key
            }
        }
        
        public init(namespace: Namespace?, key: String, defaultValue: Value) {
            self.namespace = namespace
            self.key = key
            self.defaultValue = defaultValue
        }
        
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
        
    }
    
    @propertyWrapper
    public class RawRepresentableDefault<Value: RawRepresentable>: Default<Value> {
        
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
    
    public static let version = 1
    
    @Default(namespace: nil, key: "local_version", defaultValue: 0)
    public static var localVersion: Int
    
    // Indicates that user defaults are in Main app's container and needs to migrate to AppGroup's container
    public static var needsMigration: Bool {
        localVersion == 0
    }
    
    public static var canMigrate: Bool {
        !isAppExtension
    }
    
    // Indicates that user defaults are outdated but do present in AppGroup's container
    public static var needsUpgrade: Bool {
        localVersion != 0 && version > localVersion
    }
    
    @Default(namespace: nil, key: "first_shown_home_date", defaultValue: Date())
    public static var firstShownHomeDate: Date
    
    @Default(namespace: nil, key: "currency_rates", defaultValue: [:])
    public static var currencyRates: [String: Double]
    
    @Default(namespace: nil, key: "server_index", defaultValue: 0)
    public static var serverIndex: Int
    
}

extension AppGroupUserDefaults {
    
    public static func migrateIfNeeded() {
        guard needsMigration else {
            return
        }
        Account.migrate()
        User.migrate()
        Signal.migrate()
        Crypto.migrate()
        Database.migrate()
        Wallet.migrate()
        localVersion = version
    }
    
}
