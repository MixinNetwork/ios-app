import Foundation
import CallKit
import MixinServices

class CallHandle {
    
    let id: String
    let name: String
    
    private(set) lazy var cxHandle = CXHandle(type: .generic, value: id)
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    
    convenience init(user: UserItem) {
        self.init(id: user.userId, name: user.fullName)
    }
    
    convenience init?(cxHandle: CXHandle) {
        switch cxHandle.type {
        case .generic:
            let userId = cxHandle.value
            guard let name = UserDAO.shared.getFullname(userId: userId) else {
                return nil
            }
            self.init(id: userId, name: name)
        case .phoneNumber, .emailAddress:
            // This is not expected to happen according to current CXProviderConfiguration
            return nil
        @unknown default:
            return nil
        }
    }
    
}

extension CallHandle: CustomDebugStringConvertible {
    
    var debugDescription: String {
        "CallHandle: <id: \(id), name: \(name)>"
    }
    
}
