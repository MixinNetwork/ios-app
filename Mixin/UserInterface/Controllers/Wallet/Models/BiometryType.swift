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
            return R.string.localizable.face_id()
        case .touchID:
            return R.string.localizable.touch_id()
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
    switch TIP.status {
    case .needsInitialize, .unknown:
        return .none
    case .needsMigrate, .ready:
        break
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
