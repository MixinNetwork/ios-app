import Foundation
import MixinServices

class Call {
    
    static let statusDidChangeNotification = Notification.Name("one.mixin.messenger.call-service.call-status-did-change")
    static let newCallStatusUserInfoKey = "call_stat"
    
    let uuid: UUID // Message ID of offer message
    let remoteUserId: String
    let remoteUsername: String
    let isOutgoing: Bool
    
    var status: Status = .connecting {
        didSet {
            performSynchronouslyOnMainThread {
                NotificationCenter.default.post(name: Self.statusDidChangeNotification,
                                                object: self,
                                                userInfo: [Self.newCallStatusUserInfoKey: status])
            }
        }
    }
    
    var remoteUser: UserItem?
    var connectedDate: Date?
    var hasReceivedRemoteAnswer = false
    
    private(set) lazy var uuidString = uuid.uuidString.lowercased()
    private(set) lazy var conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: remoteUserId)
    
    init(uuid: UUID, remoteUserId: String, remoteUsername: String, isOutgoing: Bool) {
        self.uuid = uuid
        self.remoteUserId = remoteUserId
        self.remoteUsername = remoteUsername
        self.isOutgoing = isOutgoing
    }
    
    convenience init(uuid: UUID, remoteUser: UserItem, isOutgoing: Bool) {
        self.init(uuid: uuid,
                  remoteUserId: remoteUser.userId,
                  remoteUsername: remoteUser.fullName,
                  isOutgoing: isOutgoing)
        self.remoteUser = remoteUser
    }
    
}

extension Call {
    
    enum Status {
        
        case incoming
        case outgoing
        case connecting
        case connected
        case disconnecting
        
        var localizedDescription: String? {
            switch self {
            case .incoming:
                return R.string.localizable.call_status_incoming()
            case .outgoing:
                return R.string.localizable.call_status_outgoing()
            case .connecting:
                return R.string.localizable.call_status_connecting()
            case .connected:
                return nil
            case .disconnecting:
                return R.string.localizable.call_status_disconnecting()
            }
        }
        
        var briefLocalizedDescription: String? {
            switch self {
            case .connected:
                return nil
            case .disconnecting:
                return R.string.localizable.call_status_done()
            default:
                return R.string.localizable.call_status_waiting()
            }
        }
        
    }
    
}
