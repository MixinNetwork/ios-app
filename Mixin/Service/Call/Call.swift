import Foundation
import MixinServices

class Call: NSObject {
    
    static let statusDidChangeNotification = Notification.Name("one.mixin.messenger.Call.StatusDidChange")
    static let statusUserInfoKey = "stat"
    
    let uuid: UUID
    let isOutgoing: Bool
    
    var connectedDate: Date?
    
    var status: Status = .connecting {
        didSet {
            NotificationCenter.default.post(name: Self.statusDidChangeNotification,
                                            object: self,
                                            userInfo: [Self.statusUserInfoKey: status])
        }
    }
    
    private(set) lazy var uuidString = uuid.uuidString.lowercased()
    
    init(uuid: UUID, isOutgoing: Bool) {
        self.uuid = uuid
        self.isOutgoing = isOutgoing
        super.init()
    }
    
}

extension Call {
    
    @objc enum Status: Int, CustomDebugStringConvertible {
        
        case incoming
        case outgoing
        case connecting
        case connected
        case disconnecting
        
        var debugDescription: String {
            switch self {
            case .incoming:
                return "incoming"
            case .outgoing:
                return "outgoing"
            case .connecting:
                return "connecting"
            case .connected:
                return "connected"
            case .disconnecting:
                return "disconnecting"
            }
        }
        
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
