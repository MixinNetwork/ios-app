import UIKit
import MixinServices

final class InscriptionPriviewViewController: AuthenticationPreviewViewController {
    
    private let operation: InscriptionPaymentOperation
    private let inscription: InscriptionItem
    
    init(inscription: InscriptionItem, operation: InscriptionPaymentOperation) {
        self.inscription = inscription
        self.operation = operation
        super.init(warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableHeaderView.setIcon(inscription: inscription)
        tableHeaderView.titleLabel.text = R.string.localizable.confirm_transfer()
        tableHeaderView.subtitleLabel.text = R.string.localizable.review_transfer_hint()
        
        var rows: [Row] = [
            .info(caption: .collectible, content: "\(inscription.collectionName ?? "") #\(inscription.sequence)")
        ]
        
        rows.append(.receivers([operation.opponent], threshold: nil))
        
        if let account = LoginManager.shared.account {
            let user = UserItem.createUser(from: account)
            rows.append(.senders([user], threshold: nil))
        }
        if !operation.memo.isEmpty {
            rows.append(.info(caption: .memo, content: operation.memo))
        }
        reloadData(with: rows)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        layoutTableHeaderView(title: R.string.localizable.sending_transfer_request(),
                              subtitle: R.string.localizable.transfer_sending_description())
        replaceTrayView(with: nil, animation: .vertical)
        Task {
            do {
                try await operation.start(pin: pin)
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .success)
                    layoutTableHeaderView(title: R.string.localizable.transfer_success(),
                                          subtitle: R.string.localizable.transfer_sent_description())
                    tableView.setContentOffset(.zero, animated: true)
                    loadFinishedTrayView()
                }
            } catch {
                let errorDescription = if let error = error as? MixinAPIError, PINVerificationFailureHandler.canHandle(error: error) {
                    await PINVerificationFailureHandler.handle(error: error)
                } else {
                    error.localizedDescription
                }
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .failure)
                    layoutTableHeaderView(title: R.string.localizable.transfer_failed(),
                                          subtitle: errorDescription,
                                          style: .destructive)
                    tableView.setContentOffset(.zero, animated: true)
                    switch error {
                    case MixinAPIResponseError.malformedPin, MixinAPIResponseError.incorrectPin, TIPNode.Error.response(.incorrectPIN), TIPNode.Error.response(.internalServer):
                        loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                                 leftAction: #selector(close(_:)),
                                                 rightTitle: R.string.localizable.retry(),
                                                 rightAction: #selector(confirm(_:)),
                                                 animation: .vertical)
                    default:
                        loadSingleButtonTrayView(title: R.string.localizable.got_it(),
                                                 action: #selector(close(_:)))
                    }
                }
            }
        }
    }

}
