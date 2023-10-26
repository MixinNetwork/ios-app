import UIKit
import MixinServices

final class RegisterToSafeViewController: UIViewController {
    
}

extension RegisterToSafeViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        "Register to Safe"
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        "Input PIN to register"
    }
    
    var options: AuthenticationIntentOptions {
        [.allowsBiometricAuthentication, .becomesFirstResponderOnAppear, .unskippable]
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        Task {
            do {
                try await TIP.registerToSafe(pin: pin)
                await MainActor.run {
                    completion(.success)
                    self.presentingViewController?.dismiss(animated: true)
                    ConcurrentJobQueue.shared.addJob(job: RefreshAccountJob())
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error: error, allowsRetrying: true))
                }
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}
