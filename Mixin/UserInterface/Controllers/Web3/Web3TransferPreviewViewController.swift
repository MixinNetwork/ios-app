import UIKit
import Combine
import BigInt
import web3
import Web3Wallet
import MixinServices

final class Web3TransferPreviewViewController: AuthenticationPreviewViewController {
    
    enum Proposer {
        case dapp(Web3DappProposer)
        case web3ToMixinWallet
        case web3ToAddress
    }
    
    var manipulateNavigationStackOnFinished = false
    
    private let operation: Web3TransferOperation
    private let proposer: Proposer?
    
    private var stateObserver: AnyCancellable?
    
    init(operation: Web3TransferOperation, proposer: Proposer?) {
        self.operation = operation
        self.proposer = proposer
        let warnings: [String] = if operation.canDecodeBalanceChange {
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
        Logger.web3.info(category: "Web3TransferView", message: "\(self) deinited")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let operationContainsSetAuthority: Bool
        if let operation = operation as? ArbitraryTransactionSolanaTransferOperation {
            operationContainsSetAuthority = operation.transactionContainsSetAuthority()
        } else {
            operationContainsSetAuthority = false
        }
        
        if operationContainsSetAuthority {
            tableHeaderView.setIcon(progress: .failure)
        } else {
            tableHeaderView.setIcon { imageView in
                if let operation = operation as? Web3TransferWithWalletConnectOperation {
                    imageView.sd_setImage(with: operation.session.iconURL)
                } else {
                    switch proposer {
                    case .dapp, .none:
                        imageView.image = R.image.unknown_session()
                    case .web3ToMixinWallet, .web3ToAddress:
                        imageView.image = R.image.web3_sign_transfer()
                    }
                }
            }
        }
        
        let title = if operation.canDecodeBalanceChange {
            R.string.localizable.web3_transaction_request()
        } else {
            R.string.localizable.signature_request()
        }
        if operationContainsSetAuthority {
            let subtitle = R.string.localizable.malicious_instruction_set_authority()
            layoutTableHeaderView(title: title, subtitle: subtitle, style: [])
        } else {
            switch proposer {
            case .dapp, .none:
                let subtitle = R.string.localizable.web3_signing_warning()
                layoutTableHeaderView(title: title, subtitle: subtitle, style: .destructive)
            case .web3ToMixinWallet, .web3ToAddress:
                let subtitle = R.string.localizable.signature_request_from(mixinMessenger)
                layoutTableHeaderView(title: title, subtitle: subtitle, style: [])
            }
        }
        
        var rows: [Row]
        if operationContainsSetAuthority {
            rows = []
        } else {
            rows = [
                .web3Message(caption: R.string.localizable.estimated_balance_change(),
                             message: R.string.localizable.loading()),
                .amount(caption: .fee,
                        token: R.string.localizable.calculating(),
                        fiatMoney: R.string.localizable.calculating(),
                        display: .byToken,
                        boldPrimaryAmount: false)
            ]
        }
        
        switch proposer {
        case .dapp(let proposer):
            rows.append(.doubleLineInfo(caption: .from, primary: proposer.name, secondary: proposer.host))
            rows.append(.info(caption: .account, content: operation.fromAddress))
        case .web3ToMixinWallet:
            if let account = LoginManager.shared.account {
                let me = UserItem.createUser(from: account)
                rows.append(.receivers([me], threshold: nil))
            }
            rows.append(.info(caption: .sender, content: operation.fromAddress))
        case .web3ToAddress:
            rows.append(.receivingAddress(value: operation.toAddress, label: nil))
            rows.append(.info(caption: .sender, content: operation.fromAddress))
        case .none:
            break
        }
        
        rows.append(.info(caption: .network, content: operation.chain.name))
        reloadData(with: rows)
        
        if operationContainsSetAuthority {
            loadSingleButtonTrayView(title: R.string.localizable.reject(), action: #selector(close(_:)))
        } else {
            stateObserver = operation.$state.sink { [weak self] state in
                self?.reloadData(state: state)
            }
            reloadData(state: operation.state)
            
            Task { [operation, weak self] in
                do {
                    let change = try await operation.loadBalanceChange()
                    await MainActor.run {
                        let row: Row
                        switch change {
                        case let .decodingFailed(rawTransaction):
                            row = .web3Message(caption: R.string.localizable.transaction(),
                                               message: rawTransaction)
                        case let .detailed(token, amount):
                            let tokenAmount = CurrencyFormatter.localizedString(from: amount, format: .precision, sign: .never)
                            let fiatMoneyValue = amount * token.decimalUSDPrice * Currency.current.decimalRate
                            let fiatMoneyAmount = CurrencyFormatter.localizedString(from: fiatMoneyValue, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
                            row = .web3Amount(caption: R.string.localizable.estimated_balance_change(),
                                              tokenAmount: tokenAmount,
                                              fiatMoneyAmount: fiatMoneyAmount,
                                              token: token)
                        }
                        self?.replaceRow(at: 0, with: row)
                    }
                } catch {
                    Logger.web3.error(category: "Web3TransferView", message: "Load bal. change: \(error)")
                }
                do {
                    let fee = try await operation.loadFee()
                    await MainActor.run {
                        let feeValue = CurrencyFormatter.localizedString(from: fee.token, format: .precision, sign: .never, symbol: nil)
                        let feeCost = if fee.fiatMoney >= 0.01 {
                            CurrencyFormatter.localizedString(from: fee.fiatMoney, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
                        } else {
                            "<" + CurrencyFormatter.localizedString(from: 0.01, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
                        }
                        let row: Row = .amount(caption: .fee,
                                               token: feeValue + " " + operation.feeToken.symbol,
                                               fiatMoney: feeCost,
                                               display: .byToken,
                                               boldPrimaryAmount: false)
                        self?.replaceRow(at: 1, with: row)
                    }
                } catch {
                    Logger.web3.error(category: "Web3TransferView", message: "Load fee: \(error)")
                }
            }
        }
    }
    
    override func performAction(with pin: String) {
        Task {
            try? await operation.start(pin: pin)
        }
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
    
    @objc func resendTransaction(_ sender: Any) {
        if operation.isResendingTransactionAvailable {
            operation.resendTransaction()
        } else {
            confirm(sender)
        }
    }
    
    private func reloadData(state: Web3TransferOperation.State) {
        var confirmButton: UIButton? {
            (trayView as? AuthenticationPreviewDoubleButtonTrayView)?.rightButton
        }
        
        switch state {
        case .loading:
            confirmButton?.isEnabled = false
        case .ready:
            confirmButton?.isEnabled = true
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
                                  subtitle: "\(error)",
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
                                  subtitle: "\(error)")
            tableView.setContentOffset(.zero, animated: true)
            loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                     leftAction: #selector(close(_:)),
                                     rightTitle: R.string.localizable.retry(),
                                     rightAction: #selector(resendTransaction(_:)),
                                     animation: .vertical)
        case .success:
            canDismissInteractively = true
            tableHeaderView.setIcon(progress: .success)
            let subtitle = if operation.canDecodeBalanceChange {
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

extension Web3TransferPreviewViewController: Web3PopupViewController {
    
    func reject() {
        operation.reject()
    }
    
}
