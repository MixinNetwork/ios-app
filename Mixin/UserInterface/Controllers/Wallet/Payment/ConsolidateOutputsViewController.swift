import UIKit
import MixinServices

final class ConsolidateOutputsViewController: UIViewController {
    
    enum Result {
        case success
        case userCancelled
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: UIImageView!
    
    var onCompletion: ((Result) -> Void)?
    
    private let token: TokenItem
    private let traceID = UUID().uuidString.lowercased()
    
    init(token: TokenItem) {
        self.token = token
        let nib = R.nib.consolidateOutputsView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
}

extension ConsolidateOutputsViewController: AuthenticationIntent {
    
    var intentTitle: String {
        ""
    }
    
    var intentTitleIcon: UIImage? {
        nil
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        ""
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
                guard let account = LoginManager.shared.account else {
                    return
                }
                let me = UserItem.createUser(from: account)
                let outputs = UTXOService.shared.collectConsolidationOutputs(kernelAssetID: token.kernelAssetID)
                let operation = TransferPaymentOperation(traceID: traceID,
                                                         spendingOutputs: outputs,
                                                         destination: .user(me),
                                                         token: token,
                                                         amount: outputs.amount,
                                                         memo: "")
                try await operation.start(pin: pin)
                await MainActor.run {
                    completion(.success)
                    controller.presentingViewController?.dismiss(animated: true, completion: { [onCompletion] in
                        onCompletion?(.success)
                    })
                }
            } catch {
                Logger.general.error(category: "Consolidation", message: "Failed to consolidate: \(error)")
                let action: AuthenticationViewController.RetryAction
                switch error {
                case MixinAPIResponseError.malformedPin, MixinAPIResponseError.incorrectPin, MixinAPIResponseError.insufficientPool, MixinAPIResponseError.internalServerError:
                    action = .inputPINAgain
                case MixinAPIResponseError.notRegisteredToSafe:
                    action = .notAllowed
                default:
                    action = .notAllowed
                }
                await MainActor.run {
                    completion(.failure(error: error, retry: action))
                }
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        onCompletion?(.userCancelled)
    }
    
}
