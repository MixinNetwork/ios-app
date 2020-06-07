import Foundation
import CallKit

enum CallHandle {
    
    case phoneNumber(String)
    case userId(String)
    
    var cxHandle: CXHandle {
        switch self {
        case .phoneNumber(let number):
            return CXHandle(type: .phoneNumber, value: number)
        case .userId(let userId):
            return CXHandle(type: .generic, value: userId)
        }
    }
    
    init?(cxHandle: CXHandle) {
        switch cxHandle.type {
        case .generic:
            self = .userId(cxHandle.value)
        case .phoneNumber:
            self = .phoneNumber(cxHandle.value)
        case .emailAddress:
            // This is not expected to happen according to current CXProviderConfiguration
            return nil
        @unknown default:
            return nil
        }
    }
    
}
