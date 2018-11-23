import Foundation

class CommonUserDefault {

    static let shared = CommonUserDefault()

    private let keyFirstLaunchSince1970 = "first_launch_since_1970"
    private let keyHasPerformedTransfer = "has_performed_transfer"
    private var keyConversationDraft: String {
        return "defalut_conversation_draft_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyLastUpdateOrInstallVersion: String {
        return "last_update_or_install_version_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyLastUpdateOrInstallDate: String {
        return "last_update_or_install_date_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyHasUnreadAnnouncement: String {
        return "default_unread_announcement_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyCameraQRCodeTips: String {
        return "default_camera_qrcode_tips_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyHasPerformedQRCodeScanning : String {
        return "has_scanned_qr_code_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyMessageNotificationShowPreview: String {
        return "msg_notification_preview_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyHasConversation: String {
        return "has_conversation_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyBackupVideos: String {
        return "backup_videos_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyBackupFiles: String {
        return "backup_files_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyBackupCategory: String {
        return "backup_category_\(AccountAPI.shared.accountIdentityNumber)"
    }

    enum BackupCategory: String {
        case daily
        case weekly
        case monthly
        case off
    }
    
    private let session = UserDefaults(suiteName: SuiteName.common)!

    var isCameraQRCodeTips: Bool {
        get {
            return session.bool(forKey: keyCameraQRCodeTips)
        }
        set {
            session.set(newValue, forKey: keyCameraQRCodeTips)
            session.synchronize()
        }
    }

    var hasPerformedQRCodeScanning: Bool {
        get {
            return session.bool(forKey: keyHasPerformedQRCodeScanning)
        }
        set {
            session.set(newValue, forKey: keyHasPerformedQRCodeScanning)
        }
    }
    
    var hasPerformedTransfer: Bool {
        get {
            return session.bool(forKey: keyHasPerformedTransfer)
        }
        set {
            session.set(newValue, forKey: keyHasPerformedTransfer)
        }
    }

    var hasBackupVideos: Bool {
        get {
            return session.bool(forKey: keyBackupVideos)
        }
        set {
            session.set(newValue, forKey: keyBackupVideos)
        }
    }

    var hasBackupFiles: Bool {
        get {
            return session.bool(forKey: keyBackupFiles)
        }
        set {
            session.set(newValue, forKey: keyBackupFiles)
        }
    }

    var backupCategory: BackupCategory {
        get {
            guard let category = session.string(forKey: keyBackupCategory) else {
                return .off
            }
            return BackupCategory(rawValue: category) ?? .off
        }
        set {
            session.set(newValue.rawValue, forKey: keyBackupCategory)
        }
    }

    var shouldShowPreviewForMessageNotification: Bool {
        get {
            if session.object(forKey: keyMessageNotificationShowPreview) != nil {
                return session.bool(forKey: keyMessageNotificationShowPreview)
            } else {
                return true
            }
        }
        set {
            session.set(newValue, forKey: keyMessageNotificationShowPreview)
        }
    }
    
    var hasConversation: Bool {
        get {
            if session.object(forKey: keyHasConversation) == nil {
                let hasValidConversation = ConversationDAO.shared.hasValidConversation()
                session.set(hasValidConversation, forKey: keyHasConversation)
                return hasValidConversation
            } else {
                return session.bool(forKey: keyHasConversation)
            }
        }
        set {
            session.set(newValue, forKey: keyHasConversation)
        }
    }
    
    private var conversationDraft: [String: Any] {
        get {
            return session.dictionary(forKey: keyConversationDraft) ?? [:]
        }
        set {
            session.set(newValue, forKey: keyConversationDraft)
        }
    }

    private var hasUnreadAnnouncement: [String: Bool] {
        get {
            return (session.dictionary(forKey: keyHasUnreadAnnouncement) as? [String : Bool]) ?? [:]
        }
        set {
            session.set(newValue, forKey: keyHasUnreadAnnouncement)
        }
    }
    
    func getConversationDraft(_ conversationId: String) -> String? {
        return conversationDraft[conversationId] as? String
    }

    func setConversationDraft(_ conversationId: String, draft: String) {
        if draft.isEmpty {
            conversationDraft.removeValue(forKey: conversationId)
        } else {
            conversationDraft[conversationId] = draft
        }
    }

    var lastUpdateOrInstallVersion: String? {
        return session.string(forKey: keyLastUpdateOrInstallVersion)
    }

    func checkUpdateOrInstallVersion() {
        if lastUpdateOrInstallVersion != Bundle.main.bundleVersion {
            session.set(Bundle.main.bundleVersion, forKey: keyLastUpdateOrInstallVersion)
            session.set(Date().toUTCString(), forKey: keyLastUpdateOrInstallDate)
        }
    }

    var firstLaunchTimeIntervalSince1970: TimeInterval {
        return session.double(forKey: keyFirstLaunchSince1970)
    }
    
    func updateFirstLaunchDateIfNeeded() {
        guard session.double(forKey: keyFirstLaunchSince1970) == 0 else {
            return
        }
        session.set(Date().timeIntervalSince1970, forKey: keyFirstLaunchSince1970)
    }
    
    var lastUpdateOrInstallTime: String {
        return session.string(forKey: keyLastUpdateOrInstallDate) ?? Date().toUTCString()
    }

    func hasUnreadAnnouncement(conversationId: String) -> Bool {
        return hasUnreadAnnouncement[conversationId] ?? false
    }
    
    func setHasUnreadAnnouncement(_ hasUnreadAnnouncement: Bool, forConversationId conversationId: String) {
        guard !conversationId.isEmpty else {
            return
        }
        self.hasUnreadAnnouncement[conversationId] = hasUnreadAnnouncement
    }

}
