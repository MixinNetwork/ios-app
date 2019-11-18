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
    private var keyBackupVideos: String {
        return "backup_videos_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyBackupFiles: String {
        return "backup_files_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyAutoBackup: String {
        return "backup_category_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyLastBackupTime: String {
        return "last_backup_time_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyLastBackupSize: String {
        return "last_backup_size_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyHasForceLogout: String {
        return "has_force_logout_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyRecentlyUsedAppIds: String {
        return "recently_used_app_ids_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyRecallTips: String {
        return "default_recall_tips_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyAutoDownloadPhotos: String {
        return "auto_download_photos_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyAutoDownloadVideos: String {
        return "auto_download_videos_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyAutoDownloadFiles: String {
        return "auto_download_files_\(AccountAPI.shared.accountIdentityNumber)"
    }
    private var keyUploadContacts: String {
        return "auto_upload_contacts_\(AccountAPI.shared.accountIdentityNumber)"
    }
    
    private let session = UserDefaults(suiteName: SuiteName.common)!

    var isUploadContacts: Bool {
        get {
            if session.object(forKey: keyUploadContacts) != nil {
                return session.bool(forKey: keyUploadContacts)
            } else {
                return ContactsManager.shared.authorization == .authorized
            }
        }
        set {
            session.set(newValue, forKey: keyUploadContacts)
        }
    }
    
    var isRecallTips: Bool {
        get {
            return session.bool(forKey: keyRecallTips)
        }
        set {
            session.set(newValue, forKey: keyRecallTips)
        }
    }

    var isCameraQRCodeTips: Bool {
        get {
            return session.bool(forKey: keyCameraQRCodeTips)
        }
        set {
            session.set(newValue, forKey: keyCameraQRCodeTips)
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

    var hasForceLogout: Bool {
        get {
            return session.bool(forKey: keyHasForceLogout)
        }
        set {
            session.set(newValue, forKey: keyHasForceLogout)
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

    var lastBackupTime: TimeInterval {
        get {
            return session.double(forKey: keyLastBackupTime)
        }
        set {
            session.set(newValue, forKey: keyLastBackupTime)
        }
    }

    var lastBackupSize: Int64? {
        get {

            return session.object(forKey: keyLastBackupSize) as? Int64
        }
        set {
            session.set(newValue, forKey: keyLastBackupSize)
        }
    }


    var backupCategory: AutoBackup {
        get {
            guard let category = session.string(forKey: keyAutoBackup) else {
                return .off
            }
            return AutoBackup(rawValue: category) ?? .off
        }
        set {
            session.set(newValue.rawValue, forKey: keyAutoBackup)
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
    
    var conversationDraft: [String: Any] {
        get {
            return session.dictionary(forKey: keyConversationDraft) ?? [:]
        }
        set {
            session.set(newValue, forKey: keyConversationDraft)
        }
    }

    var hasUnreadAnnouncement: [String: Bool] {
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
        let lastVersion = lastUpdateOrInstallVersion
        if lastVersion != Bundle.main.bundleVersion {
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
    
    private(set) var recentlyUsedAppIds: [String] {
        get {
            return session.stringArray(forKey: keyRecentlyUsedAppIds) ?? []
        }
        set {
            session.set(newValue, forKey: keyRecentlyUsedAppIds)
        }
    }
    
    var autoDownloadPhotos: AutoDownload {
        get {
            if let value = session.object(forKey: keyAutoDownloadPhotos) as? Int, let status = AutoDownload(rawValue: value) {
                return status
            } else {
                return .wifiAndCellular
            }
        }
        set {
            session.set(newValue.rawValue, forKey: keyAutoDownloadPhotos)
        }
    }
    
    var autoDownloadVideos: AutoDownload {
        get {
            if let value = session.object(forKey: keyAutoDownloadVideos) as? Int, let status = AutoDownload(rawValue: value) {
                return status
            } else {
                return .never
            }
        }
        set {
            session.set(newValue.rawValue, forKey: keyAutoDownloadVideos)
        }
    }
    
    var autoDownloadFiles: AutoDownload {
        get {
            if let value = session.object(forKey: keyAutoDownloadFiles) as? Int, let status = AutoDownload(rawValue: value) {
                return status
            } else {
                return .never
            }
        }
        set {
            session.set(newValue.rawValue, forKey: keyAutoDownloadFiles)
        }
    }
    
}
