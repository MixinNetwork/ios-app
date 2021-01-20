import Foundation

public enum EdDSAMigration {
    
    public static var needsMigration: Bool {
        let hasLegacySessionSecret: Bool
        if let secret = AppGroupUserDefaults.Account.sessionSecret {
            hasLegacySessionSecret = !secret.isEmpty
        } else {
            hasLegacySessionSecret = false
        }
        let needsMigration = hasLegacySessionSecret
            && AppGroupUserDefaults.Account.serializedAccount != nil
        return needsMigration
    }
    
}
