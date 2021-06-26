import Foundation

enum MixinURL {
    
    static let scheme = "mixin"
    static let host = "mixin.one"
    
    private typealias Host = Path
    
    private struct Path {
        static let codes = "codes"
        static let pay = "pay"
        static let users = "users"
        static let transfer = "transfer"
        static let send = "send"
        static let device = "device"
        static let auth = "auth"
        static let withdrawal = "withdrawal"
        static let address = "address"
        static let apps = "apps"
        static let snapshots = "snapshots"
        static let conversations = "conversations"
    }
    
    case codes(String)
    case users(String)
    case apps(String)
    case snapshots
    case conversations(conversationId: String, userId: String?)
    case pay
    case transfer(String)
    case send(ExternalSharingContext)
    case device(id: String, publicKey: String)
    case unknown(URL)
    case withdrawal
    case address
    case upgradeDesktop
    
    init?(url: URL) {
        if url.scheme == MixinURL.scheme {
            if url.host == Host.codes && url.pathComponents.count == 2 {
                self = .codes(url.pathComponents[1])
            } else if url.host == Host.pay {
                self = .pay
            } else if url.host == Host.users && url.pathComponents.count == 2 {
                self = .users(url.pathComponents[1])
            } else if url.host == Host.snapshots {
                self = .snapshots
            } else if url.host == Host.conversations && url.pathComponents.count == 2 {
                self = .conversations(conversationId: url.pathComponents[1],
                                      userId: url.getKeyVals()["user"].uuidString)
            } else if url.host == Host.apps && url.pathComponents.count == 2 {
                self = .apps(url.pathComponents[1])
            } else if url.host == Host.transfer && url.pathComponents.count == 2 {
                self = .transfer(url.pathComponents[1])
            } else if url.host == Host.send, let context = ExternalSharingContext(url: url) {
                self = .send(context)
            } else if url.host == Host.device {
                if url.pathComponents.count == 2, url.pathComponents[1] == Path.auth, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems, let publicKey = items.first(where: { $0.name == "pub_key" })?.value, !publicKey.isEmpty {
                    if let id = items.first(where: { $0.name == "id" })?.value, !id.isEmpty {
                        self = .device(id: id, publicKey: publicKey)
                    } else {
                        self = .upgradeDesktop
                    }
                } else {
                    self = .unknown(url)
                }
            } else if url.host == Host.withdrawal {
                self = .withdrawal
            } else if url.host == Host.address {
                self = .address
            } else {
                self = .unknown(url)
            }
        } else if url.host == MixinURL.host {
            if url.pathComponents.count == 3 && url.pathComponents[1] == Path.codes {
                self = .codes(url.pathComponents[2])
            } else if url.pathComponents.count > 1 && url.pathComponents[1] == Path.pay {
                self = .pay
            } else if url.pathComponents.count == 3 && url.pathComponents[1] == Path.users {
                self = .users(url.pathComponents[2])
            } else if url.pathComponents.count > 1 && url.pathComponents[1] == Path.snapshots {
                self = .snapshots
            } else if url.pathComponents.count == 3 && url.pathComponents[1] == Path.conversations {
                self = .conversations(conversationId: url.pathComponents[2],
                                      userId: url.getKeyVals()["user"].uuidString)
            } else if url.pathComponents.count == 3 && url.pathComponents[1] == Path.apps {
                self = .apps(url.pathComponents[2])
            } else if url.pathComponents.count == 3 && url.pathComponents[1] == Path.transfer {
                self = .transfer(url.pathComponents[2])
            } else if url.pathComponents.count > 1 && url.pathComponents[1] == Path.withdrawal {
                self = .withdrawal
            } else if url.pathComponents.count > 1 && url.pathComponents[1] == Path.address {
                self = .address
            } else {
                self = .unknown(url)
            }
        } else {
            return nil
        }
    }
    
    init?(string: String) {
        guard let url = URL(string: string) else {
            return nil
        }
        self.init(url: url)
    }
    
}
