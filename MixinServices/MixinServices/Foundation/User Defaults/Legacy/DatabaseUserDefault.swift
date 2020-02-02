import Foundation

internal class DatabaseUserDefault {

    static let shared = DatabaseUserDefault()

    private var keyMixinDatabaseVersion: String {
        return "key_database_mixin_version_\(myIdentityNumber)"
    }
    private var keyUpgradeStickers: String {
        return "key_upgrade_stickers_\(myIdentityNumber)"
    }
    private var keyDatabaseVersion: String {
        return "key_database_version_\(myIdentityNumber)"
    }
    private var keyForceUpgradeDatabase: String {
        return "key_force_upgrade_database_\(myIdentityNumber)"
    }
    private var keyLastVacuumTime: String {
        return "key_last_vacuum_time_\(myIdentityNumber)"
    }
    private var keyClearSentSenderKey: String {
        return "key_clear_sent_sender_key_\(myIdentityNumber)"
    }

    private let session = UserDefaults(suiteName: SuiteName.database)!
    let currentDatabaseVersion = 8

    var databaseVersion: Int? {
        get {
            return session.object(forKey: keyDatabaseVersion) as? Int
        }
        set {
            session.set(newValue, forKey: keyDatabaseVersion)
        }
    }

    func hasUpgradeDatabase() -> Bool {
        return forceUpgradeDatabase || databaseVersion != currentDatabaseVersion
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

    var forceUpgradeDatabase: Bool {
        get {
            return session.bool(forKey: keyForceUpgradeDatabase)
        }
        set {
            session.set(newValue, forKey: keyForceUpgradeDatabase)
        }
    }

    var lastVacuumTime: TimeInterval {
        get {
            return session.double(forKey: keyLastVacuumTime)
        }
        set {
            session.set(newValue, forKey: keyLastVacuumTime)
        }
    }

    var clearSentSenderKey: Bool {
        get {
            return session.bool(forKey: keyClearSentSenderKey)
        }
        set {
            session.set(newValue, forKey: keyClearSentSenderKey)
        }
    }
}
