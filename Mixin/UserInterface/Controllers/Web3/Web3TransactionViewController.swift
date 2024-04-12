import UIKit
import Combine
import BigInt
import web3
import Web3Wallet
import MixinServices

final class Web3TransactionViewController: AuthenticationPreviewViewController {
    
    private let operation: Web3TransactionOperation
    
    private var stateObserver: AnyCancellable?
    
    init(operation: Web3TransactionOperation) {
        self.operation = operation
        let warnings: [String] = if operation.canDecodeValue {
            []
        } else {
            [R.string.localizable.decode_transaction_failed()]
        }
        super.init(warnings: warnings)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        Logger.web3.info(category: "TxnRequest", message: "\(self) deinited")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        stateObserver = operation.$state.sink { [weak self] state in
            self?.reloadData(state: state)
        }
        reloadData(state: .pending)
        var confirmButton: UIButton? {
            (trayView as? AuthenticationPreviewDoubleButtonTrayView)?.rightButton
        }
        confirmButton?.isEnabled = false
        operation.loadGas { fee in
            self.reloadFeeRow(with: fee)
            confirmButton?.isEnabled = true
        }
    }
    
    override func performAction(with pin: String) {
        operation.start(with: pin)
    }
    
    override func close(_ sender: Any) {
        super.close(sender)
        operation.rejectTransactionIfNotSent()
    }
    
    override func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        super.presentationControllerDidDismiss(presentationController)
        operation.rejectTransactionIfNotSent()
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
    
    private func reloadData(state: Web3TransactionOperation.State) {
        switch state {
        case .pending:
            tableHeaderView.setIcon { imageView in
                if let operation = operation as? Web3TransactionWithWalletConnectOperation {
                    imageView.sd_setImage(with: operation.session.iconURL)
                } else {
                    imageView.image = R.image.unknown_session()
                }
            }
            let title = if operation.canDecodeValue {
                R.string.localizable.web3_transaction_request()
            } else {
                R.string.localizable.signature_request()
            }
            layoutTableHeaderView(title: title, subtitle: R.string.localizable.web3_ensure_trust())
            var rows: [Row] = [
                .amount(caption: .fee,
                        token: R.string.localizable.calculating(),
                        fiatMoney: R.string.localizable.calculating(),
                        display: .byToken,
                        boldPrimaryAmount: false),
                .proposer(name: operation.proposer.name, host: operation.proposer.host),
                .info(caption: .account, content: operation.address),
                .info(caption: .network, content: operation.chain.name)
            ]
            let transactionRow: Row
            if let tokenValue = operation.transactionPreview.decimalValue, tokenValue != 0 {
                let tokenAmount = CurrencyFormatter.localizedString(from: tokenValue, format: .precision, sign: .never)
                let fiatMoneyValue = tokenValue * operation.chainToken.decimalUSDPrice * Currency.current.decimalRate
                let fiatMoneyAmount = CurrencyFormatter.localizedString(from: fiatMoneyValue, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
                transactionRow = .web3Amount(caption: R.string.localizable.estimated_balance_change(),
                                             tokenAmount: tokenAmount,
                                             fiatMoneyAmount: fiatMoneyAmount,
                                             token: operation.chainToken)
            } else {
                transactionRow = .web3Message(caption: R.string.localizable.transaction(),
                                              message: operation.transactionPreview.hexData ?? "")
            }
            rows.insert(transactionRow, at: 0)
            reloadData(with: rows)
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
                                  subtitle: error.localizedDescription)
            tableView.setContentOffset(.zero, animated: true)
            loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                     leftAction: #selector(close(_:)),
                                     rightTitle: R.string.localizable.retry(),
                                     rightAction: #selector(operation.resendTransaction(_:)),
                                     animation: .vertical)
        case .success:
            canDismissInteractively = true
            tableHeaderView.setIcon(progress: .success)
            let subtitle = if operation.canDecodeValue {
                R.string.localizable.web3_signing_transaction_success()
            } else {
                R.string.localizable.web3_signing_data_success()
            }
            layoutTableHeaderView(title: R.string.localizable.sending_success(), subtitle: subtitle)
            tableView.setContentOffset(.zero, animated: true)
            loadSingleButtonTrayView(title: R.string.localizable.done(), action: #selector(close(_:)))
        }
    }
    
}

extension Web3TransactionViewController: Web3PopupViewController {
    
    func reject() {
        operation.reject()
    }
    
}

extension Web3TransactionViewController {
    
    private func reloadFeeRow(with selected: Web3TransactionOperation.Fee) {
        let row: Row = .amount(caption: .fee,
                               token: selected.feeValue + " " + operation.chain.feeSymbol,
                               fiatMoney: selected.feeCost,
                               display: .byToken,
                               boldPrimaryAmount: false)
        replaceRow(at: 1, with: row)
    }
    
}
