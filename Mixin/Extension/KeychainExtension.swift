import Foundation
import LocalAuthentication
import MixinServices

extension Keychain {

    @discardableResult
    func storePIN(pin: String) -> Bool {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if context.biometryType == .touchID {
                let prompt = R.string.localizable.enable_pay(R.string.localizable.touch_ID())
                return storePIN(pin: pin, prompt: prompt)
            } else if context.biometryType == .faceID {
                let prompt = R.string.localizable.enable_pay(R.string.localizable.face_ID())
                return storePIN(pin: pin, prompt: prompt)
            }
        }

        return false
    }

}
