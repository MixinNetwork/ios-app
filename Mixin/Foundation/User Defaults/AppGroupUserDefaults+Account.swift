import Foundation

extension AppGroupUserDefaults {
    
    public enum Account {
        
        enum Key: String, CaseIterable {
            case account
            case sessionSecret = "session_secret"
            case pinToken = "pin_token"
            case isClockSkewed = "clock_skew"
            case canRestoreChat = "can_restore_chat"
            case canRestoreMedia = "can_restore_media"
            case hasUnfinishedBackup = "has_unfinished_backup"
            case extensionSession = "extension_session"
            case lastDesktopLoginDate = "last_desktop_login_date"
        }
        
        @Default(namespace: .account, key: Key.account, defaultValue: nil)
        public static var serializedAccount: Data?
        
        @Default(namespace: .account, key: Key.sessionSecret, defaultValue: nil)
        public static var sessionSecret: String?
        
        @Default(namespace: .account, key: Key.pinToken, defaultValue: nil)
        public static var pinToken: String?
        
        @Default(namespace: .account, key: Key.isClockSkewed, defaultValue: false)
        public static var isClockSkewed: Bool
        
        @Default(namespace: .account, key: Key.canRestoreChat, defaultValue: false)
        public static var canRestoreChat: Bool
        
        @Default(namespace: .account, key: Key.canRestoreMedia, defaultValue: false)
        public static var canRestoreMedia: Bool
        
        @Default(namespace: .account, key: Key.hasUnfinishedBackup, defaultValue: false)
        public static var hasUnfinishedBackup: Bool
        
        @Default(namespace: .account, key: Key.extensionSession, defaultValue: nil)
        public static var extensionSession: String?
        
        @Default(namespace: .account, key: Key.lastDesktopLoginDate, defaultValue: nil)
        public static var lastDesktopLoginDate: Date?
        
        public static var isDesktopLoggedIn: Bool {
            guard let sessionId = extensionSession else {
                return false
            }
            return !sessionId.isEmpty
        }
        
        public static func clearAll() {
            Key.allCases
                .map({ $0.rawValue })
                .forEach(defaults.removeObject(forKey:))
            defaults.synchronize()
        }
        
        internal static func migrate() {
            serializedAccount = AccountUserDefault.shared.serializedAccount
            sessionSecret = AccountUserDefault.shared.getToken()
            pinToken = AccountUserDefault.shared.getPinToken()
            isClockSkewed = AccountUserDefault.shared.hasClockSkew
            canRestoreChat = AccountUserDefault.shared.hasRestoreChat
            canRestoreMedia = AccountUserDefault.shared.hasRestoreMedia
            hasUnfinishedBackup = AccountUserDefault.shared.hasRebackup
            extensionSession = AccountUserDefault.shared.extensionSession
            lastDesktopLoginDate = AccountUserDefault.shared.lastDesktopLogin
        }
        
    }
    
}
