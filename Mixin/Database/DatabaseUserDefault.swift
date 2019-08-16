import Foundation

class DatabaseUserDefault {

    static let shared = DatabaseUserDefault()

    private var keySignalDatabaseVersion: String {
        return "key_database_signal"
    }
    private var keyMixinDatabaseVersion: String {
        return "key_database_mixin_version_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyTaskDatabaseVersion: String {
        return "key_database_task_version_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyUpgradeStickers: String {
        return "key_upgrade_stickers_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyDatabaseVersion: String {
        return "key_database_version_\(AccountAPI.shared.accountIdentityNumber)"
    }

    private let session = UserDefaults(suiteName: SuiteName.database)!
    let currentDatabaseVersion = 1

    var databaseVersion: Int {
        get {
            return session.integer(forKey: keyDatabaseVersion)
        }
        set {
            session.set(newValue, forKey: keyDatabaseVersion)
        }
    }

    func hasUpgradeDatabase() -> Bool {
        guard mixinDatabaseVersion > 0 || databaseVersion > 0 else {
            databaseVersion = currentDatabaseVersion
            return false
        }
        return databaseVersion != currentDatabaseVersion
    }

    var mixinDatabaseVersion: Int {
        get {
            return session.integer(forKey: keyMixinDatabaseVersion)
        }
        set {
            session.set(newValue, forKey: keyMixinDatabaseVersion)
        }
    }

    var taskDatabaseVersion: Int {
        get {
            return session.integer(forKey: keyTaskDatabaseVersion)
        }
        set {
            session.set(newValue, forKey: keyTaskDatabaseVersion)
        }
    }

    var signalDatabaseVersion: Int {
        get {
            return session.integer(forKey: keySignalDatabaseVersion)
        }
        set {
            session.set(newValue, forKey: keySignalDatabaseVersion)
        }
    }

    var upgradeStickers: Bool {
        get {
            return session.bool(forKey: keyUpgradeStickers)
        }
        set {
            session.set(newValue, forKey: keyUpgradeStickers)
        }
    }

}
