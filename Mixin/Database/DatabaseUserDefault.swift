import Foundation

class DatabaseUserDefault {

    static let shared = DatabaseUserDefault()

    private var keyMixinDatabaseVersion: String {
        return "key_database_mixin_version_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyUpgradeStickers: String {
        return "key_upgrade_stickers_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyDatabaseVersion: String {
        return "key_database_version_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyInitiatedFTS: String {
        return "key_initiated_fts_\(AccountAPI.shared.accountIdentityNumber)"
    }

    private let session = UserDefaults(suiteName: SuiteName.database)!
    let currentDatabaseVersion = 2

    var databaseVersion: Int {
        get {
            return session.integer(forKey: keyDatabaseVersion)
        }
        set {
            session.set(newValue, forKey: keyDatabaseVersion)
        }
    }

    func hasUpgradeDatabase() -> Bool {
        return databaseVersion != currentDatabaseVersion
    }

    var mixinDatabaseVersion: Int {
        return session.integer(forKey: keyMixinDatabaseVersion)
    }

    var upgradeStickers: Bool {
        get {
            return session.bool(forKey: keyUpgradeStickers)
        }
        set {
            session.set(newValue, forKey: keyUpgradeStickers)
        }
    }

    var initiatedFTS: Bool {
        get {
            return session.bool(forKey: keyInitiatedFTS)
        }
        set {
            session.set(newValue, forKey: keyInitiatedFTS)
        }
    }

}
