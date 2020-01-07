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
                let prompt = R.string.localizable.wallet_store_encrypted_pin(R.string.localizable.wallet_touch_id())
                return storePIN(pin: pin, prompt: prompt)
            } else if context.biometryType == .faceID {
                let prompt = R.string.localizable.wallet_store_encrypted_pin(R.string.localizable.wallet_face_id())
                return storePIN(pin: pin, prompt: prompt)
            }
        }

        return false
    }

}
