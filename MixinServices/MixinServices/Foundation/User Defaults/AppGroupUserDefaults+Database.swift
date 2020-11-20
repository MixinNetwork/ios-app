import Foundation

extension AppGroupUserDefaults {
    
    public enum Database {
        
        @Default(namespace: .database, key: "vacuum_date", defaultValue: .distantPast)
        public static var vacuumDate: Date
        
        @Default(namespace: .database, key: "sent_sender_key_cleared", defaultValue: true)
        public static var isSentSenderKeyCleared: Bool
        
        @Default(namespace: .database, key: "fts_initialized", defaultValue: false)
        public static var isFTSInitialized: Bool
        
        @Default(namespace: .database, key: "fts_offset", defaultValue: 0)
        public static var ftsOffset: Int
        
        internal static func migrate() {
            vacuumDate = Date(timeIntervalSince1970: DatabaseUserDefault.shared.lastVacuumTime)
            isSentSenderKeyCleared = !DatabaseUserDefault.shared.clearSentSenderKey
        }
        
    }
    
}
