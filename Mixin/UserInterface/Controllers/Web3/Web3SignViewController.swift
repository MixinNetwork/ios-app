import UIKit
import Combine
import web3
import Web3Wallet
import MixinServices

final class Web3SignViewController: AuthenticationPreviewViewController {
    
    enum SignRequestError: Error {
        case mismatchedAddress
    }
    
    private let operation: Web3SignOperation
    private let chainName: String
    
    private var stateObserver: AnyCancellable?
    
    init(operation: Web3SignOperation, chainName: String) {
        self.operation = operation
        self.chainName = chainName
        super.init(warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        stateObserver = operation.$state.sink { [weak self] state in
            self?.reloadData(state: state)
        }
        reloadData(state: operation.state)
    }
    
    override func close(_ sender: Any) {
        super.close(sender)
        operation.rejectRequestIfSignatureNotSent()
    }
    
    override func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        super.presentationControllerDidDismiss(presentationController)
        operation.rejectRequestIfSignatureNotSent()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRow row: Row) {
        switch row {
        case let .web3Message(_, message):
            let preview = R.nib.textPreviewView(withOwner: nil)!
            preview.textView.text = message
            preview.show(on: AppDelegate.current.mainWindow)
        default:
            break
        }
    }
    
    override func performAction(with pin: String) {
        operation.start(with: pin)
    }
    
    private func reloadData(state: Web3SignOperation.State) {
        switch state {
        case .pending:
            tableHeaderView.setIcon { imageView in
                if let operation = operation as? Web3SignWithWalletConnectOperation {
                    imageView.sd_setImage(with: operation.session.iconURL)
                } else {
                    imageView.image = R.image.web3_sign_transfer()
                }
            }
            layoutTableHeaderView(title: R.string.localizable.web3_message_request(),
                                  subtitle: R.string.localizable.web3_ensure_trust())
            let feeTokenValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never)
            let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            reloadData(with: [
                .web3Message(caption: R.string.localizable.unsigned_message(), message: operation.humanReadableMessage),
                .amount(caption: .fee, token: feeTokenValue, fiatMoney: feeFiatMoneyValue, display: .byToken, boldPrimaryAmount: false),
                .doubleLineInfo(caption: .from, primary: operation.proposer.name, secondary: operation.proposer.host),
                .info(caption: .account, content: operation.address),
                .info(caption: .network, content: chainName)
            ])
        case .signing:
            canDismissInteractively = false
            tableHeaderView.setIcon(progress: .busy)
            layoutTableHeaderView(title: R.string.localizable.web3_signing(),
                                  subtitle: R.string.localizable.web3_ensure_trust())
            replaceTrayView(with: nil, animation: .vertical)
        case .signingFailed(let error):
            canDismissInteractively = true
            tableHeaderView.setIcon(progress: .failure)
            layoutTableHeaderView(title: R.string.localizable.web3_signing_failed(),
                                  subtitle: error.localizedDescription,
                                  style: .destructive)
            tableView.setContentOffset(.zero, animated: true)
            loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                     leftAction: #selector(close(_:)),
                                     rightTitle: R.string.localizable.retry(),
                                     rightAction: #selector(confirm(_:)),
                                     animation: .vertical)
        case .sending:
            layoutTableHeaderView(title: R.string.localizable.sending(),
                                  subtitle: R.string.localizable.web3_ensure_trust())
        case .sendingFailed(let error):
            canDismissInteractively = true
            tableHeaderView.setIcon(progress: .failure)
            layoutTableHeaderView(title: R.string.localizable.sending_failed(),
                                  subtitle: error.localizedDescription,
                                  style: .destructive)
            tableView.setContentOffset(.zero, animated: true)
            loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                     leftAction: #selector(close(_:)),
                                     rightTitle: R.string.localizable.retry(),
                                     rightAction: #selector(operation.resendSignature(_:)),
                                     animation: .vertical)
        case .success:
            canDismissInteractively = true
            tableHeaderView.setIcon(progress: .success)
            layoutTableHeaderView(title: R.string.localizable.sending_success(),
                                  subtitle: R.string.localizable.web3_signing_message_success())
            tableView.setContentOffset(.zero, animated: true)
            loadSingleButtonTrayView(title: R.string.localizable.done(),
                                     action:  #selector(close(_:)))
        }
    }
    
}

extension Web3SignViewController: Web3PopupViewController {
    
    func reject() {
        operation.reject()
    }
    
}
