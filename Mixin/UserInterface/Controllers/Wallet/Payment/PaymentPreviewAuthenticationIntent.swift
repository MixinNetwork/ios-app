import Foundation

final class PaymentPreviewAuthenticationIntent: AuthenticationIntent {
    
    let intentTitle: String
    let intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? = nil
    let intentSubtitle = ""
    let options: AuthenticationIntentOptions = [
        .allowsBiometricAuthentication,
        .becomesFirstResponderOnAppear,
        .unskippable,
        .neverRequestAddBiometricAuthentication
    ]
    let authenticationViewController: AuthenticationViewController? = nil
    
    private let onInput: (String) -> Void
    
    init(title: String, onInput: @escaping (String) -> Void) {
        self.intentTitle = title
        self.onInput = onInput
    }
    
    @MainActor
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        completion(.success)
        controller.presentingViewController?.dismiss(animated: true, completion: {
            self.onInput(pin)
        })
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}
