import UIKit
import LocalAuthentication
import MixinServices

enum BiometryType {
    case faceID
    case touchID
    case none
    
    var localizedName: String {
        switch self {
        case .faceID:
            return R.string.localizable.wallet_face_id()
        case .touchID:
            return R.string.localizable.wallet_touch_id()
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
    guard LoginManager.shared.account?.has_pin ?? false else {
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
