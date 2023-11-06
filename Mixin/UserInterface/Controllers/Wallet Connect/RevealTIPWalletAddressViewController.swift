import UIKit
import MixinServices

final class RevealTIPWalletAddressViewController: UIViewController {
    
    @MainActor var onApprove: ((Data) -> Void)?
    
}

extension RevealTIPWalletAddressViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        "Reveal Address"
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        "Reveal your TIP Wallet address"
    }
    
    var options: AuthenticationIntentOptions {
        [.allowsBiometricAuthentication, .becomesFirstResponderOnAppear]
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        Task {
            do {
                let priv = try await TIP.ethereumPrivateKey(pin: pin)
                await MainActor.run {
                    completion(.success)
                    self.dismiss(animated: true) {
                        self.onApprove?(priv)
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
