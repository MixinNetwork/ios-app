import Foundation

class CommonUserDefault {

    static let shared = CommonUserDefault()

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
    
    func getConversationDraft(_ conversationId: String) -> String {
        return conversationDraft[conversationId] as? String ?? ""
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
