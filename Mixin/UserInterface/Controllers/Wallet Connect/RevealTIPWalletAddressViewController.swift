import UIKit
import MixinServices

final class RevealTIPWalletAddressViewController: UIViewController {
    
    @MainActor var onApprove: ((Data) -> Void)?
    
}

extension RevealTIPWalletAddressViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        "Reveal Address"
    }
    
    var intentSubtitleIconURL: URL? {
        nil
    }
    
    var intentSubtitle: String {
        "Reveal your TIP Wallet address"
    }
    
    var isBiometryAuthAllowed: Bool {
        true
    }
    
    var inputPINOnAppear: Bool {
        true
    }
    
    func authenticationViewController(_ controller: AuthenticationViewController, didInput pin: String, completion: @escaping @MainActor (Swift.Error?) -> Void) {
        Task {
            do {
                let priv = try await TIP.ethereumPrivateKey(pin: pin)
                await MainActor.run {
                    completion(nil)
                    self.dismiss(animated: true) {
                        self.onApprove?(priv)
                    }
                }
            } catch {
                await MainActor.run {
                    completion(error)
                }
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}
