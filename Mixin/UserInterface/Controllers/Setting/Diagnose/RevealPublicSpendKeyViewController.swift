import UIKit
import CryptoKit
import MixinServices

final class RevealPublicSpendKeyIntent: AuthenticationIntent {
    
    @MainActor var onReveal: ((String) -> Void)?
    
    var intentTitle: String {
        "Input PIN to Reveal"
    }
    
    var intentTitleIcon: UIImage? {
        nil
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        R.string.localizable.diagnose_warning_hint()
    }
    
    var options: AuthenticationIntentOptions {
        [.neverRequestAddBiometricAuthentication, .becomesFirstResponderOnAppear, .multipleLineSubtitle]
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        Task {
            do {
                let spendKey = try await TIP.spendPriv(pin: pin)
                let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: spendKey)
                let publicKey = privateKey.publicKey.rawRepresentation.hexEncodedString()
                await MainActor.run {
                    completion(.success)
                    controller.presentingViewController?.dismiss(animated: true) {
                        self.onReveal?(publicKey)
                    }
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error: error, retry: .inputPINAgain))
                }
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}
