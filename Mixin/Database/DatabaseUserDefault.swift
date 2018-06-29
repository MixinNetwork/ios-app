import Foundation

class DatabaseUserDefault {

    static let shared = DatabaseUserDefault()

    private var keyMixinDatabaseVersion: String {
        return "key_database_mixin_version_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keySignalDatabaseVersion: String {
        return "key_database_signal_version_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyUpgradeStickers: String {
        return "key_upgrade_stickers_\(AccountAPI.shared.accountIdentityNumber)"
    }

    private let session = UserDefaults(suiteName: SuiteName.database)!

    var mixinDatabaseVersion: Int {
        get {
            return session.integer(forKey: keyMixinDatabaseVersion)
        }
        set {
            session.set(newValue, forKey: keyMixinDatabaseVersion)
            session.synchronize()
        }
    }

    var signalDatabaseVersion: Int {
        get {
            return session.integer(forKey: keySignalDatabaseVersion)
        }
        set {
            session.set(newValue, forKey: keySignalDatabaseVersion)
            session.synchronize()
        }
    }

    var upgradeStickers: Bool {
        get {
            return session.bool(forKey: keyUpgradeStickers)
        }
        set {
            session.set(newValue, forKey: keyUpgradeStickers)
            session.synchronize()
        }
    }

}
