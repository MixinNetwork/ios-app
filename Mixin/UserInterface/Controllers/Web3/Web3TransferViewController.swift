import UIKit
import Combine
import BigInt
import web3
import Web3Wallet
import MixinServices

final class Web3TransferViewController: AuthenticationPreviewViewController {
    
    enum Proposer {
        case dapp(Web3DappProposer)
        case web3ToMixinWallet
        case web3ToAddress
    }
    
    var manipulateNavigationStackOnFinished = false
    
    private let operation: Web3TransferOperation
    private let proposer: Proposer
    
    private var stateObserver: AnyCancellable?
    
    init(operation: Web3TransferOperation, proposer: Proposer) {
        self.operation = operation
        self.proposer = proposer
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
        operation.loadGas { [weak self, weak confirmButton] fee in
            self?.reloadFeeRow(with: fee)
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
    
    private func reloadData(state: Web3TransferOperation.State) {
        switch state {
        case .pending:
            tableHeaderView.setIcon { imageView in
                if let operation = operation as? Web3TransferWithWalletConnectOperation {
                    imageView.sd_setImage(with: operation.session.iconURL)
                } else {
                    switch proposer {
                    case .dapp:
                        imageView.image = R.image.unknown_session()
                    case .web3ToMixinWallet, .web3ToAddress:
                        imageView.image = R.image.web3_sign_transfer()
                    }
                }
            }
            
            let title = if operation.canDecodeValue {
                R.string.localizable.web3_transaction_request()
            } else {
                R.string.localizable.signature_request()
            }
            let subtitle = switch proposer {
            case .dapp:
                R.string.localizable.web3_ensure_trust()
            case .web3ToMixinWallet, .web3ToAddress:
                R.string.localizable.web3_request_from_mixin()
            }
            layoutTableHeaderView(title: title, subtitle: subtitle)
            
            var rows: [Row]
            if let tokenValue = operation.transactionPreview.decimalValue, tokenValue != 0 {
                // A non-zero `decimalValue` indicates spending native token
                let tokenAmount = CurrencyFormatter.localizedString(from: tokenValue, format: .precision, sign: .never)
                let fiatMoneyValue = tokenValue * operation.chainToken.decimalUSDPrice * Currency.current.decimalRate
                let fiatMoneyAmount = CurrencyFormatter.localizedString(from: fiatMoneyValue, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
                rows = [
                    .web3Amount(caption: R.string.localizable.estimated_balance_change(),
                                tokenAmount: tokenAmount,
                                fiatMoneyAmount: fiatMoneyAmount,
                                token: operation.chainToken)
                ]
            } else {
                rows = [
                    .web3Message(caption: R.string.localizable.transaction(),
                                 message: operation.transactionPreview.hexData ?? "")
                ]
            }
            
            rows.append(
                .amount(caption: .fee,
                        token: R.string.localizable.calculating(),
                        fiatMoney: R.string.localizable.calculating(),
                        display: .byToken,
                        boldPrimaryAmount: false)
            )
            
            switch proposer {
            case .dapp(let proposer):
                rows.append(.proposer(name: proposer.name, host: proposer.host))
                rows.append(.info(caption: .account, content: operation.fromAddress))
            case .web3ToMixinWallet:
                if let account = LoginManager.shared.account {
                    let me = UserItem.createUser(from: account)
                    rows.append(.receivers([me], threshold: nil))
                }
                rows.append(.info(caption: .sender, content: operation.fromAddress))
            case .web3ToAddress:
                let receiver = operation.transactionPreview.to.toChecksumAddress()
                rows.append(.receivingAddress(value: receiver, label: nil))
                rows.append(.info(caption: .sender, content: operation.fromAddress))
            }
            
            rows.append(.info(caption: .network, content: operation.chain.name))
            
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
            if manipulateNavigationStackOnFinished,
               let navigationController = UIApplication.homeNavigationController,
               let home = navigationController.viewControllers.first
            {
                navigationController.setViewControllers([home], animated: false)
            }
        }
    }
    
}

extension Web3TransferViewController: Web3PopupViewController {
    
    func reject() {
        operation.reject()
    }
    
}

extension Web3TransferViewController {
    
    private func reloadFeeRow(with selected: Web3TransferOperation.Fee) {
        let weiFee = (selected.gasLimit * selected.gasPrice).description
        guard let decimalWeiFee = Decimal(string: weiFee, locale: .enUSPOSIX) else {
            return
        }
        let decimalFee = decimalWeiFee * .wei
        let cost = decimalFee * operation.chainToken.decimalUSDPrice * Currency.current.decimalRate
        let feeValue = CurrencyFormatter.localizedString(from: decimalFee, format: .networkFee, sign: .never, symbol: nil)
        let feeCost = if cost >= 0.01 {
            CurrencyFormatter.localizedString(from: cost, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        } else {
            "<" + CurrencyFormatter.localizedString(from: 0.01, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        }
        let row: Row = .amount(caption: .fee,
                               token: feeValue + " " + operation.chain.feeSymbol,
                               fiatMoney: feeCost,
                               display: .byToken,
                               boldPrimaryAmount: false)
        replaceRow(at: 1, with: row)
    }
    
}