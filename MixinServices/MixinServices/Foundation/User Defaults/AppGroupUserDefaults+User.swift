import Foundation

extension AppGroupUserDefaults {
    
    public enum User {
        
        enum Key: String, CaseIterable {
            case localVersion = "local_version"
            case needsRebuildDatabase = "needs_rebuild_database"
            case lastUpdateOrInstallDate = "last_update_or_install_date"
            case lastUpdateOrInstallVersion = "last_update_or_install_version"
            
            case loginPINValidated = "tip_initialized"
            case hasShownRecallTips = "session_secret"
            case hasPerformedTransfer = "has_performed_transfer"
            
            case autoBackup = "auto_backup"
            case backupVideos = "backup_videos"
            case backupFiles = "backup_files"
            case lastBackupDate = "last_backup_date"
            case lastBackupSize = "last_backup_size"
            
            case showMessagePreviewInNotification = "show_message_preview_in_notification"
            case duplicateTransferConfirmation = "duplicate_transfer_confirmation"
            case conversationDraft = "conversation_draft"
            case currentConversationId = "current_conversation_id"
            case reloadConversation = "reload_conversation"
            case hasUnreadAnnouncement = "has_unread_announcement"
            case closeScamAnnouncementDate = "close_scam_announcement_date"
            case recentlyUsedAppIds = "recently_used_app_ids"
            
            case autoUploadsContacts = "auto_uploads_contacts"
            case autoDownloadPhotos = "auto_download_photos"
            case autoDownloadVideos = "auto_download_videos"
            case autoDownloadFiles = "auto_download_files"

            case hasRecoverMedia = "has_recover_media"
            case hasRestoreUploadAttachment = "has_restore_upload_attachment"
            
            case circleId = "circle_id"
            case circleName = "circle_name"
            case isCircleSynchronized = "is_circle_synchronized"
            
            case clips = "clips"
            case assetSearchHistory = "asset_search_history"
            case recentSearches = "recent_searches"
            
            case recoveryContactTipDismissalDate = "emergency_contact_bulletin_dismissal_date"
            case backupMnemonicsTipDismissalDate = "backup_mnemonics_tip_dismissal_date"
            case verifyPhoneTipDismissalDate = "verify_phone_tip_dismissal_date"
            
            case lockScreenTimeout = "lock_screen_timeout_interval"
            case lockScreenWithBiometricAuthentication = "lock_screen_with_biometric_authentication"
            case lastLockScreenBiometricVerifiedDate = "last_lock_screen_biometric_verified_date"
            
            case userInterfaceStyle = "ui_style"

            case pinMessageBanners = "pin_message_banners"
            
            case stickerRefreshDate = "sticker_refresh_date"
            case hasNewStickers = "has_new_stickers"
            
            case externalSchemes = "external_schemes"
            case externalSchemesRefreshDate = "external_schemes_refresh_date"
            
            case wallpapers = "wallpapers"
            case chatFontSize = "chat_font_size"
            case useSystemFont = "use_system_font"
            case exploreSegmentIndex = "explore_segment_index"
            
            case collectibleContent = "collectible_content"
            case collectibleOrdering = "collectible_order"
            case marketCategory = "market_category"
            case marketChangePeriod = "market_change_period"
            case marketColorAppearance = "color_appearance"
        }
        
        public static let version = 33
        public static let uninitializedVersion = -1
        public static let deviceTransferVersion = 1
        
        public static let didChangeRecentlyUsedAppIdsNotification = Notification.Name(rawValue: "one.mixin.services.recently.used.app.ids.change")
        public static let didChangeUserInterfaceStyleNotification = Notification.Name(rawValue: "one.mixin.services.DidChangeUserInterfaceStyle")
        public static let circleNameDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.circle.name.change")
        public static let homeAppIdsDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.home.app.ids.change")
        public static let pinMessageBannerDidChangeNotification = Notification.Name("one.mixin.services.pinMessageBannerDidChange")
        public static let hasNewStickersDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.hasNewStickersDidChangeNotification")
        public static let marketColorAppearanceDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.MarketColorAppearanceChange")
        public static let recentSearchesDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.RecentSearchesChange")
        
        private static let maxNumberOfAssetSearchHistory = 2
        private static let maxNumberOfRecentSearches = 4
        
        public static var needsUpgradeInMainApp: Bool {
            return localVersion < version
                || needsRebuildDatabase
                || TaskDatabase.current.needsMigration
                || SignalDatabase.current.needsMigration
                || UserDatabase.current.needsMigration
                || Web3Database.current.needsMigration
        }
        
        @Default(namespace: .user, key: Key.localVersion, defaultValue: uninitializedVersion)
        public static var localVersion: Int
        
        @Default(namespace: .user, key: Key.needsRebuildDatabase, defaultValue: false)
        public static var needsRebuildDatabase: Bool
        
        @Default(namespace: .user, key: Key.lastUpdateOrInstallDate, defaultValue: Date())
        public private(set) static var lastUpdateOrInstallDate: Date
        
        @Default(namespace: .user, key: Key.lastUpdateOrInstallVersion, defaultValue: "")
        private static var lastUpdateOrInstallVersion: String
        
        @Default(namespace: .user, key: Key.hasShownRecallTips, defaultValue: false)
        public static var hasShownRecallTips: Bool
        
        @Default(namespace: .user, key: Key.loginPINValidated, defaultValue: false)
        public static var loginPINValidated: Bool
        
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
        
        @Default(namespace: .user, key: Key.duplicateTransferConfirmation, defaultValue: true)
        public static var duplicateTransferConfirmation: Bool
        
        @Default(namespace: .user, key: Key.conversationDraft, defaultValue: [:])
        public static var conversationDraft: [String: String]

        @Default(namespace: .user, key: Key.currentConversationId, defaultValue: nil)
        public static var currentConversationId: String?

        @Default(namespace: .user, key: Key.reloadConversation, defaultValue: false)
        public static var reloadConversation: Bool
        
        @Default(namespace: .user, key: Key.hasUnreadAnnouncement, defaultValue: [:])
        public static var hasUnreadAnnouncement: [String: Bool]
        
        // Key is user ID
        @Default(namespace: .user, key: Key.closeScamAnnouncementDate, defaultValue: [:])
        public static var closeScamAnnouncementDate: [String: Date]
        
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

        @Default(namespace: .user, key: Key.hasRecoverMedia, defaultValue: false)
        public static var hasRecoverMedia: Bool

        @Default(namespace: .user, key: Key.hasRestoreUploadAttachment, defaultValue: false)
        public static var hasRestoreUploadAttachment: Bool
        
        @Default(namespace: .user, key: Key.circleId, defaultValue: nil)
        public static var circleId: String?

        @Default(namespace: .user, key: Key.isCircleSynchronized, defaultValue: false)
        public static var isCircleSynchronized: Bool
        
        @Default(namespace: .user, key: Key.circleName, defaultValue: nil)
        public static var circleName: String? {
            didSet {
                NotificationCenter.default.post(onMainThread: circleNameDidChangeNotification, object: self)
            }
        }
        
        @Default(namespace: .user, key: Key.clips, defaultValue: [])
        public static var clips: [Data]
        
        // Stores asset id
        @Default(namespace: .user, key: Key.assetSearchHistory, defaultValue: [])
        public private(set) static var assetSearchHistory: [String]
        
        @Default(namespace: .user, key: Key.recentSearches, defaultValue: [])
        private static var recentSearchItems: [Data] {
            didSet {
                NotificationCenter.default.post(onMainThread: recentSearchesDidChangeNotification, object: self)
            }
        }
        
        @Default(namespace: .user, key: Key.recoveryContactTipDismissalDate, defaultValue: nil)
        public static var recoveryContactTipDismissalDate: Date?
        
        @Default(namespace: .user, key: Key.backupMnemonicsTipDismissalDate, defaultValue: nil)
        public static var backupMnemonicsTipDismissalDate: Date?
        
        @Default(namespace: .user, key: Key.verifyPhoneTipDismissalDate, defaultValue: nil)
        public static var verifyPhoneTipDismissalDate: Date?
        
        @Default(namespace: .user, key: Key.lockScreenWithBiometricAuthentication, defaultValue: false)
        public static var lockScreenWithBiometricAuthentication: Bool
        
        @Default(namespace: .user, key: Key.lockScreenTimeout, defaultValue: 60 * 5)
        public static var lockScreenTimeoutInterval: TimeInterval
           
        @Default(namespace: .user, key: Key.lastLockScreenBiometricVerifiedDate, defaultValue: nil)
        public static var lastLockScreenBiometricVerifiedDate: Date?
        
        @RawRepresentableDefault(namespace: .user, key: Key.userInterfaceStyle, defaultValue: .unspecified)
        public static var userInterfaceStyle: UIUserInterfaceStyle {
            didSet {
                NotificationCenter.default.post(onMainThread: didChangeUserInterfaceStyleNotification, object: self)
            }
        }
        
        @Default(namespace: .user, key: Key.pinMessageBanners, defaultValue: [:])
        public static var pinMessageBanners: [String: String] {
            didSet {
                NotificationCenter.default.post(onMainThread: Self.pinMessageBannerDidChangeNotification, object: self)
            }
        }
        
        @Default(namespace: .user, key: Key.stickerRefreshDate, defaultValue: nil)
        public static var stickerRefreshDate: Date?
        
        @Default(namespace: .user, key: Key.hasNewStickers, defaultValue: false)
        public static var hasNewStickers: Bool {
            didSet {
                NotificationCenter.default.post(onMainThread: hasNewStickersDidChangeNotification, object: self)
            }
        }
        
        @Default(namespace: .user, key: Key.externalSchemes, defaultValue: [])
        public static var externalSchemes: [String]
        
        @Default(namespace: .crypto, key: Key.externalSchemesRefreshDate, defaultValue: .distantPast)
        public static var externalSchemesRefreshDate: Date
        
        @Default(namespace: .user, key: Key.wallpapers, defaultValue: [:])
        public static var wallpapers: [String: String]
        
        @RawRepresentableDefault(namespace: .user, key: Key.chatFontSize, defaultValue: .regular)
        public static var chatFontSize: ChatFontSize {
            didSet {
                NotificationCenter.default.post(name: UIContentSizeCategory.didChangeNotification, object: nil)
            }
        }
        
        @Default(namespace: .user, key: Key.useSystemFont, defaultValue: true)
        public static var useSystemFont: Bool {
            didSet {
                NotificationCenter.default.post(name: UIContentSizeCategory.didChangeNotification, object: nil)
            }
        }
        
        @Default(namespace: .user, key: Key.exploreSegmentIndex, defaultValue: 0)
        public static var exploreSegmentIndex: Int
        
        @RawRepresentableDefault(namespace: .user, key: Key.collectibleContent, defaultValue: .item)
        public static var collectibleContent: CollectibleDisplayContent
        
        @RawRepresentableDefault(namespace: .user, key: Key.collectibleOrdering, defaultValue: .recent)
        public static var collectibleOrdering: CollectibleDisplayOrdering
        
        @RawRepresentableDefault(namespace: .user, key: Key.marketCategory, defaultValue: .all)
        public static var marketCategory: Market.Category
        
        @RawRepresentableDefault(namespace: .user, key: Key.marketChangePeriod, defaultValue: .sevenDays)
        public static var marketChangePeriod: Market.ChangePeriod
        
        @RawRepresentableDefault(namespace: .user, key: Key.marketColorAppearance, defaultValue: .greenUpRedDown)
        public static var marketColorAppearance: MarketColorAppearance {
            didSet {
                NotificationCenter.default.post(name: Self.marketColorAppearanceDidChangeNotification, object: nil)
            }
        }
        
        public static var recentSearches: [RecentSearch] {
            recentSearchItems.compactMap(RecentSearch.init(rawValue:))
        }
        
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
        
        public static func insertAssetSearchHistory(with id: String) {
            guard !assetSearchHistory.contains(id) else {
                return
            }
            var history = assetSearchHistory
            history.insert(id, at: 0)
            AppGroupUserDefaults.User.assetSearchHistory = Array(history.prefix(maxNumberOfAssetSearchHistory))
        }
        
        public static func insertRecentSearch(_ item: RecentSearch) {
            var items = recentSearchItems
            
            let data = item.rawValue
            if let index = items.firstIndex(of: data) {
                items.remove(at: index)
            }
            items.insert(data, at: 0)
            if items.count > maxNumberOfRecentSearches {
                items.removeLast(items.count - maxNumberOfRecentSearches)
            }
            
            recentSearchItems = items
        }
        
        public static func removeAllRecentSearches() {
            recentSearchItems = []
        }
        
        internal static func migrate() {
            localVersion = DatabaseUserDefault.shared.databaseVersion ?? uninitializedVersion
            needsRebuildDatabase = DatabaseUserDefault.shared.forceUpgradeDatabase
            lastUpdateOrInstallDate = CommonUserDefault.shared.lastUpdateOrInstallTime.toUTCDate()
            
            hasShownRecallTips = CommonUserDefault.shared.isRecallTips
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
