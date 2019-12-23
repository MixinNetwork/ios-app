import Foundation

extension AppGroupUserDefaults {
    
    public enum Database {
        
        enum Key: String, CaseIterable {
            case isStickersUpgraded = "stickers_upgraded"
            case vacuumDate = "vacuum_date"
            case isSentSenderKeyCleared = "sent_sender_key_cleared"
        }
        
        @Default(namespace: .database, key: Key.isStickersUpgraded, defaultValue: false)
        public static var isStickersUpgraded: Bool
        
        @Default(namespace: .database, key: Key.vacuumDate, defaultValue: .distantPast)
        public static var vacuumDate: Date
        
        @Default(namespace: .database, key: Key.isSentSenderKeyCleared, defaultValue: false)
        public static var isSentSenderKeyCleared: Bool
        
        internal static func migrate() {
            isStickersUpgraded = DatabaseUserDefault.shared.upgradeStickers
            vacuumDate = Date(timeIntervalSince1970: DatabaseUserDefault.shared.lastVacuumTime)
            isSentSenderKeyCleared = !DatabaseUserDefault.shared.clearSentSenderKey
        }
        
    }
    
}
