import Foundation

extension AppGroupUserDefaults {
    
    public enum User {
        
        enum Key: String, CaseIterable {
            case localVersion = "local_version"
            case needsRebuildDatabase = "needs_rebuild_database"
            case lastUpdateOrInstallDate = "last_update_or_install_date"
            case lastUpdateOrInstallVersion = "last_update_or_install_version"
            case isLogoutByServer = "logged_out_by_server"
            
            case hasShownRecallTips = "session_secret"
            case hasShownCameraQrCodeTips = "shown_camera_qrcode_tips"
            case hasPerformedQrCodeScanning = "has_scanned_qr_code"
            case hasPerformedTransfer = "has_performed_transfer"
            
            case autoBackup = "auto_backup"
            case backupVideos = "backup_videos"
            case backupFiles = "backup_files"
            case lastBackupDate = "last_backup_date"
            case lastBackupSize = "last_backup_size"
            
            case showMessagePreviewInNotification = "show_message_preview_in_notification"
            case conversationDraft = "conversation_draft"
            case hasUnreadAnnouncement = "has_unread_announcement"
            case recentlyUsedAppIds = "recently_used_app_ids"
            
            case autoUploadsContacts = "auto_uploads_contacts"
            case autoDownloadPhotos = "auto_download_photos"
            case autoDownloadVideos = "auto_download_videos"
            case autoDownloadFiles = "auto_download_files"
        }
        
        public static let version = 9
        
        public static let didChangeRecentlyUsedAppIdsNotification = Notification.Name(rawValue: "one.mixin.services.recently.used.app.ids.change")
        
        @Default(namespace: .user, key: Key.localVersion, defaultValue: 0)
        public static var localVersion: Int
        
        @Default(namespace: .user, key: Key.needsRebuildDatabase, defaultValue: false)
        public static var needsRebuildDatabase: Bool
        
        public static var needsUpgradeInMainApp: Bool {
            return localVersion < version || needsRebuildDatabase
        }
        
        @Default(namespace: .user, key: Key.lastUpdateOrInstallDate, defaultValue: Date())
        public private(set) static var lastUpdateOrInstallDate: Date
        
        @Default(namespace: .user, key: Key.lastUpdateOrInstallVersion, defaultValue: "")
        private static var lastUpdateOrInstallVersion: String
        
        @Default(namespace: .user, key: Key.isLogoutByServer, defaultValue: false)
        public static var isLogoutByServer: Bool
        
        @Default(namespace: .user, key: Key.hasShownRecallTips, defaultValue: false)
        public static var hasShownRecallTips: Bool
        
        @Default(namespace: .user, key: Key.hasShownCameraQrCodeTips, defaultValue: false)
        public static var hasShownCameraQrCodeTips: Bool
        
        @Default(namespace: .user, key: Key.hasPerformedQrCodeScanning, defaultValue: false)
        public static var hasPerformedQrCodeScanning: Bool
        
        @Default(namespace: .user, key: Key.hasPerformedTransfer, defaultValue: false)
        public static var hasPerformedTransfer: Bool
        
        @RawRepresentableDefault(namespace: .user, key: Key.autoBackup, defaultValue: .off)
        public static var autoBackup: AutoBackup
        
        @Default(namespace: .user, key: Key.backupVideos, defaultValue: false)
        public static var backupVideos: Bool
        
        @Default(namespace: .user, key: Key.backupFiles, defaultValue: false)
        public static var backupFiles: Bool
        
        @Default(namespace: .user, key: Key.lastBackupDate, defaultValue: nil)
        public static var lastBackupDate: Date?
        
        @Default(namespace: .user, key: Key.lastBackupSize, defaultValue: nil)
        public static var lastBackupSize: Int64?
        
        @Default(namespace: .user, key: Key.showMessagePreviewInNotification, defaultValue: true)
        public static var showMessagePreviewInNotification: Bool
        
        @Default(namespace: .user, key: Key.conversationDraft, defaultValue: [:])
        public static var conversationDraft: [String: String]
        
        @Default(namespace: .user, key: Key.hasUnreadAnnouncement, defaultValue: [:])
        public static var hasUnreadAnnouncement: [String: Bool]
        
        @Default(namespace: .user, key: Key.recentlyUsedAppIds, defaultValue: [])
        public private(set) static var recentlyUsedAppIds: [String]
        
        @Default(namespace: .user, key: Key.autoUploadsContacts, defaultValue: false)
        public static var autoUploadsContacts: Bool
        
        @RawRepresentableDefault(namespace: .user, key: Key.autoDownloadPhotos, defaultValue: .wifiAndCellular)
        public static var autoDownloadPhotos: AutoDownload
        
        @RawRepresentableDefault(namespace: .user, key: Key.autoDownloadVideos, defaultValue: .never)
        public static var autoDownloadVideos: AutoDownload
        
        @RawRepresentableDefault(namespace: .user, key: Key.autoDownloadFiles, defaultValue: .never)
        public static var autoDownloadFiles: AutoDownload
        
        public static func insertRecentlyUsedAppId(id: String) {
            let maxNumberOfIds = 12
            var ids = recentlyUsedAppIds
            ids.removeAll(where: { $0 == id })
            ids.insert(id, at: 0)
            if ids.count > maxNumberOfIds {
                ids.removeLast(ids.count - maxNumberOfIds)
            }
            recentlyUsedAppIds = ids
            NotificationCenter.default.post(name: Self.didChangeRecentlyUsedAppIdsNotification, object: self)
        }
        
        public static func updateLastUpdateOrInstallDateIfNeeded() {
            guard lastUpdateOrInstallVersion != Bundle.main.bundleVersion else {
                return
            }
            lastUpdateOrInstallVersion = Bundle.main.bundleVersion
            lastUpdateOrInstallDate = Date()
        }
        
        internal static func migrate() {
            localVersion = DatabaseUserDefault.shared.databaseVersion
            needsRebuildDatabase = DatabaseUserDefault.shared.forceUpgradeDatabase
            lastUpdateOrInstallDate = CommonUserDefault.shared.lastUpdateOrInstallTime.toUTCDate()
            isLogoutByServer = CommonUserDefault.shared.hasForceLogout
            
            hasShownRecallTips = CommonUserDefault.shared.isRecallTips
            hasShownCameraQrCodeTips = CommonUserDefault.shared.isCameraQRCodeTips
            hasPerformedQrCodeScanning = CommonUserDefault.shared.hasPerformedQRCodeScanning
            hasPerformedTransfer = CommonUserDefault.shared.hasPerformedTransfer
            
            autoBackup = CommonUserDefault.shared.backupCategory
            backupVideos = CommonUserDefault.shared.hasBackupVideos
            backupFiles = CommonUserDefault.shared.hasBackupFiles
            lastBackupDate = Date(timeIntervalSince1970: CommonUserDefault.shared.lastBackupTime)
            lastBackupSize = CommonUserDefault.shared.lastBackupSize
            
            showMessagePreviewInNotification = CommonUserDefault.shared.shouldShowPreviewForMessageNotification
            conversationDraft = CommonUserDefault.shared.conversationDraft as? [String: String] ?? [:]
            hasUnreadAnnouncement = CommonUserDefault.shared.hasUnreadAnnouncement
            recentlyUsedAppIds = CommonUserDefault.shared.recentlyUsedAppIds
            
            autoUploadsContacts = CommonUserDefault.shared.isUploadContacts
            autoDownloadPhotos = CommonUserDefault.shared.autoDownloadPhotos
            autoDownloadVideos = CommonUserDefault.shared.autoDownloadVideos
            autoDownloadFiles = CommonUserDefault.shared.autoDownloadFiles
        }
        
    }
    
}
