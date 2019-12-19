import UIKit
import LocalAuthentication

enum BiometryType {
    case faceID
    case touchID
    case none
    
    var localizedName: String {
        switch self {
        case .faceID:
            return Localized.WALLET_FACE_ID
        case .touchID:
            return Localized.WALLET_TOUCH_ID
        case .none:
            return ""
        }
    }
}

private let context = LAContext()

var biometryType: BiometryType {
    guard !UIDevice.isJailbreak else {
        return .none
    }
    guard Account.current?.has_pin ?? false else {
        return .none
    }
    var error: NSError?
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        default:
            return .none
        }
    } else {
        return .none
    }
}
