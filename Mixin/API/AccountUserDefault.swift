import Foundation

class AccountUserDefault {

    private let keyAccount = "Account"
    private let keySessionSecret = "session_secret"
    private let keyPinToken = "pin_token"
    private var keyHasClockSkew = "has_clock_skew"
    private var keyHasRestoreChat = "has_restore_chat"
    private var keyHasRestoreFilesAndVideos = "has_restore_files_videos"
    private var keyHasRestoreMedia = "has_restore_media"
    private var keyExtensionSession = "extension_session"
    private var keyLastDesktopLogIn = "last_desktop_login"
    
    static let shared = AccountUserDefault()

    private let session = UserDefaults.standard

    func storeAccount(account: Account?) {
        if let account = account {
            if let data = try? JSONEncoder().encode(account) {
                session.setValue(data, forKey: keyAccount)
            }
            NotificationCenter.default.post(name: .AccountDidChange, object: nil)
        } else {
            session.removeObject(forKey: keyAccount)
        }
    }

    func getAccount() -> Account? {
        guard let data = session.value(forKey: keyAccount) as? Data, let account = try? JSONDecoder().decode(Account.self, from: data) else {
            return nil
        }
        return account
    }

    var extensionSession: String? {
        get {
            return session.string(forKey: keyExtensionSession)
        }
        set {
            session.set(newValue, forKey: keyExtensionSession)
        }
    }

    var isDesktopLoggedIn: Bool {
        guard let sessionId = extensionSession else {
            return false
        }
        return !sessionId.isEmpty
    }
    
    var lastDesktopLogin: Date? {
        get {
            return session.object(forKey: keyLastDesktopLogIn) as? Date
        }
        set {
            session.set(newValue, forKey: keyLastDesktopLogIn)
        }
    }
    
    func getToken() -> String? {
        return session.string(forKey: keySessionSecret)
    }

    func getPinToken() -> String? {
        return session.string(forKey: keyPinToken)
    }

    func storePinToken(pinToken: String) {
        session.setValue(pinToken, forKey: keyPinToken)
        session.synchronize()
    }

    func storeToken(token: String) {
        session.setValue(token, forKey: keySessionSecret)
        session.synchronize()
    }

    var hasClockSkew: Bool {
        get {
            return session.bool(forKey: keyHasClockSkew)
        }
        set {
            session.set(newValue, forKey: keyHasClockSkew)
        }
    }

    var hasRestoreChat: Bool {
        get {
            return session.bool(forKey: keyHasRestoreChat)
        }
        set {
            session.set(newValue, forKey: keyHasRestoreChat)
        }
    }

    @available(*, deprecated)
    var hasRestoreFilesAndVideos: Bool {
        get {
            return session.bool(forKey: keyHasRestoreFilesAndVideos)
        }
        set {
            session.set(newValue, forKey: keyHasRestoreFilesAndVideos)
        }
    }

    var hasRestoreMedia: Bool {
        get {
            return restoreMedia.count > 0
        }
        set {
            if newValue {
                let categories = [
                    MixinFile.ChatDirectory.photos.rawValue,
                    MixinFile.ChatDirectory.audios.rawValue,
                    MixinFile.ChatDirectory.files.rawValue,
                    MixinFile.ChatDirectory.videos.rawValue
                ]
                session.set(categories, forKey: keyHasRestoreMedia)
            } else {
                session.set([], forKey: keyHasRestoreMedia)
            }
        }
    }

    var restoreMedia: [String] {
        get {
            return session.stringArray(forKey: keyHasRestoreMedia) ?? []
        }
        set {
            session.set(newValue, forKey: keyHasRestoreMedia)
        }
    }

    func removeMedia(category: String) {
        var categories = restoreMedia
        if let idx = categories.firstIndex(of: category) {
            categories.remove(at: idx)
            restoreMedia = categories
        }
    }

    func clear() {
        if let appDomain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: appDomain)
            UserDefaults.standard.synchronize()
        }
    }
}
