import Foundation

extension AppGroupUserDefaults {
    
    public enum Database {
        
        @Default(namespace: .database, key: "vacuum_date", defaultValue: .distantPast)
        public static var vacuumDate: Date
        
        @Default(namespace: .database, key: "sent_sender_key_cleared", defaultValue: true)
        public static var isSentSenderKeyCleared: Bool
        
        // There were "fts_initialized" and "fts_v2_initialized" have been distributed
        // with internal betas. We decided to start it over again just ignore them
        @Default(namespace: .database, key: "fts_v3_initialized", defaultValue: false)
        public static var isFTSInitialized: Bool
        
        internal static func migrate() {
            vacuumDate = Date(timeIntervalSince1970: DatabaseUserDefault.shared.lastVacuumTime)
            isSentSenderKeyCleared = !DatabaseUserDefault.shared.clearSentSenderKey
        }
        
    }
    
}
