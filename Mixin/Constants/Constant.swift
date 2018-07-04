import Foundation
import UIKit

extension NSNotification.Name {

    static let SocketStatusChanged = NSNotification.Name("one.mixin.ios.websocket.status.changed")

    static let ConversationDidChange = NSNotification.Name("one.mixin.ios.sqlite.messages.changed")

    static let AccountDidChange = NSNotification.Name("one.mixin.ios.account.changed")

    static let ContactsDidChange = NSNotification.Name("one.mixin.ios.contacts.changed")

    static let UserDidChange = NSNotification.Name("one.mixin.ios.user.changed")

    static let ErrorMessageDidAppear = NSNotification.Name("one.mixin.ios.error.message")

    static let ToastMessageDidAppear = NSNotification.Name("one.mixin.ios.toast.message")

    static let ParticipantDidChange = NSNotification.Name("one.mixin.ios.participant.changed")

    static let AssetsDidChange = NSNotification.Name("one.mixin.ios.assets.changed")

    static let AssetVisibleDidChange = NSNotification.Name("one.mixin.ios.asset.visible.changed")

    static let SnapshotDidChange = NSNotification.Name("one.mixin.ios.snapshot.changed")

    static let AddressDidChange = NSNotification.Name("one.mixin.ios.addresses.changed")

    static let DefaultAddressDidChange = NSNotification.Name("one.mixin.ios.addresses.default.changed")

    static let StickerDidChange = NSNotification.Name("one.mixin.ios.stickers.changed")

    static let StorageUsageDidChange = NSNotification.Name("one.mixin.ios.storage.changed")
}

enum NotificationIdentifier: String {
    case replyAction
    case muteAction
    case actionCategory
    case showInAppNotification
}

struct ConversationChange {
    
    let conversationId: String
    let action: Action
    
    enum Action {
        case reload
        case update(conversation: ConversationItem)
        case updateConversation(conversation: ConversationResponse)
        case addMessage(message: MessageItem)
        case updateGroupIcon(iconUrl: String)
        case updateMessage(messageId: String)
        case updateMessageStatus(messageId: String, newStatus: MessageStatus)
        case updateMediaStatus(messageId: String, mediaStatus: MediaStatus)
        case updateUploadProgress(messageId: String, progress: Double)
        case updateDownloadProgress(messageId: String, progress: Double)
        case startedUpdateConversation
    }
    
}

struct SuiteName {
    static var crypto = "one.mixin.ios.crypto"
    static var common = "one.mixin.ios.common"
    static var database = "one.mixin.ios.database"
    static var wallet = "one.mixin.ios.wallet"
}

struct Storyboard {
    static let home = UIStoryboard(name: "Home", bundle: Bundle.main)
    static let login = UIStoryboard(name: "Login", bundle: Bundle.main)
    static let chat = UIStoryboard(name: "Chat", bundle: Bundle.main)
    static let contact = UIStoryboard(name: "Contact", bundle: Bundle.main)
    static let camera = UIStoryboard(name: "Camera", bundle: Bundle.main)
    static let common = UIStoryboard(name: "Common", bundle: Bundle.main)
    static let group = UIStoryboard(name: "Group", bundle: Bundle.main)
    static let wallet = UIStoryboard(name: "Wallet", bundle: Bundle.main)
    static let setting = UIStoryboard(name: "Setting", bundle: Bundle.main)
    static let photo = UIStoryboard(name: "Photo", bundle: Bundle.main)
}

struct MixinFile {
    
    enum ChatDirectory: String {
        case photos = "Photos"
        case files = "Files"
        case videos = "Videos"
        case audios = "Audios"
    }

    static var rootDirectory: URL {
        let dir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(AccountAPI.shared.accountIdentityNumber)
        _ = FileManager.default.createNobackupDirectory(dir)
        return dir
    }

    static var logPath: URL {
        let url = rootDirectory.appendingPathComponent("Log")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }

    static var databasePath: String {
        return rootDirectory.appendingPathComponent("mixin.db").path
    }

    static var signalDatabasePath: String {
        let dir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        return dir.appendingPathComponent("signal.db").path
    }

    static func url(ofChatDirectory directory: ChatDirectory, filename: String) -> URL {
        let url = rootDirectory.appendingPathComponent("Chat").appendingPathComponent(directory.rawValue)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url.appendingPathComponent(filename)
    }

    static var groupIconsUrl: URL {
        let url = rootDirectory.appendingPathComponent("Group").appendingPathComponent("Icons")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }

}

enum MixinURL {
    
    static let scheme = "mixin"
    static let host = "mixin.one"
    
    struct Path {
        static let codes = "codes"
        static let pay = "pay"
        static let users = "users"
        static let transfer = "transfer"
        static let send = "send"
    }
    typealias Host = Path
    
    case codes(String)
    case users(String)
    case pay
    case transfer(String)
    case send
    case unknown
    
    init?(url: URL) {
        if url.scheme == MixinURL.scheme {
            if url.host == Host.codes && url.pathComponents.count == 2 {
                self = .codes(url.pathComponents[1])
            } else if url.host == Host.pay {
                self = .pay
            } else if url.host == Host.users && url.pathComponents.count == 2 {
                self = .users(url.pathComponents[1])
            } else if url.host == Host.transfer && url.pathComponents.count == 2 {
                self = .transfer(url.pathComponents[1])
            } else if url.host == Host.send {
                self = .send
            } else {
                self = .unknown
            }
        } else if url.host == MixinURL.host {
            if url.pathComponents.count == 3 && url.pathComponents[1] == Path.codes {
                self = .codes(url.pathComponents[2])
            } else if url.pathComponents.count > 1 && url.pathComponents[1] == Path.pay {
                self = .pay
            } else if url.pathComponents.count == 3 && url.pathComponents[1] == Path.users {
                self = .users(url.pathComponents[2])
            } else if url.pathComponents.count == 3 && url.pathComponents[1] == Path.transfer {
                self = .transfer(url.pathComponents[2])
            } else {
                self = .unknown
            }
        } else {
            return nil
        }
    }
    
}

let muteDuration8H: Int64 = 8 * 60 * 60
let muteDuration1Week: Int64 = 7 * 24 * 60 * 60
let muteDuration1Year: Int64 = 365 * 24 * 60 * 60

enum ExtensionName: String {
    
    case jpeg = "jpg"
    case mp4 = "mp4"
    case html = "html"
    case ogg = "ogg"
    
    var withDot: String {
        return "." + rawValue
    }
    
}
