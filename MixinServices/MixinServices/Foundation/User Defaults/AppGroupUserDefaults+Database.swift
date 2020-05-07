import Foundation

extension AppGroupUserDefaults {
    
    public enum Database {
        
        enum Key: String, CaseIterable {
            case vacuumDate = "vacuum_date"
            case isSentSenderKeyCleared = "sent_sender_key_cleared"
        }
        
        @Default(namespace: .database, key: Key.vacuumDate, defaultValue: .distantPast)
        public static var vacuumDate: Date
        
        @Default(namespace: .database, key: Key.isSentSenderKeyCleared, defaultValue: true)
        public static var isSentSenderKeyCleared: Bool
        
        internal static func migrate() {
            vacuumDate = Date(timeIntervalSince1970: DatabaseUserDefault.shared.lastVacuumTime)
            isSentSenderKeyCleared = !DatabaseUserDefault.shared.clearSentSenderKey
        }
        
    }
    
}
