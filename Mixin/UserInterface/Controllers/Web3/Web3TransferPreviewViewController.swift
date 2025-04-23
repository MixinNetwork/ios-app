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
        case speedUp
        case cancel
    }
    
    var manipulateNavigationStackOnFinished = false
    
    private let operation: Web3TransferOperation
    private let proposer: Proposer?
    
    private var stateObserver: AnyCancellable?
    
    init(operation: Web3TransferOperation, proposer: Proposer?) {
        self.operation = operation
        self.proposer = proposer
        super.init(warnings: [])
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
                    imageView.image = switch proposer {
                    case .dapp, .none:
                        R.image.unknown_session()
                    case .web3ToMixinWallet, .web3ToAddress:
                        R.image.web3_sign_transfer()
                    case .speedUp:
                        R.image.speedup_transaction()
                    case .cancel:
                        R.image.cancel_transaction()
                    }
                }
            }
        }
        
        let title = switch proposer {
        case .dapp, .web3ToMixinWallet, .web3ToAddress, .none:
            R.string.localizable.web3_transaction_request()
        case .speedUp:
            R.string.localizable.speed_up_transaction()
        case .cancel:
            R.string.localizable.cancel_transaction()
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
            case .speedUp:
                let subtitle = R.string.localizable.speed_up_transaction_description()
                layoutTableHeaderView(title: title, subtitle: subtitle, style: [])
            case .cancel:
                let subtitle = R.string.localizable.cancel_transaction_description()
                layoutTableHeaderView(title: title, subtitle: subtitle, style: [])
            }
        }
        
        var rows: [Row] = []
        
        let balanceChangeIndex: Int?
        let feeIndex: Int?
        if operationContainsSetAuthority {
            balanceChangeIndex = nil
            feeIndex = nil
        } else {
            switch proposer {
            case .cancel:
                // No balance change for cancellation
                balanceChangeIndex = nil
                feeIndex = 0
            default:
                rows.append(
                    .web3Message(
                        caption: R.string.localizable.estimated_balance_change(),
                        message: R.string.localizable.loading()
                    )
                )
                balanceChangeIndex = 0
                feeIndex = 1
            }
            rows.append(
                .amount(
                    caption: .fee,
                    token: R.string.localizable.calculating(),
                    fiatMoney: R.string.localizable.calculating(),
                    display: .byToken,
                    boldPrimaryAmount: false
                )
            )
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
        case .speedUp, .cancel:
            break
        case .none:
            break
        }
        
        rows.append(.info(caption: .network, content: operation.chain.name))
        reloadData(with: rows)
        
        if operationContainsSetAuthority {
            loadSingleButtonTrayView(title: R.string.localizable.reject(), action: #selector(close(_:)))
            return
        }
        
        stateObserver = operation.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.reloadData(state: state)
            }
        reloadData(state: operation.state)
        
        Task {
            if let index = feeIndex {
                do {
                    try await self.loadFee(replacingRowAt: index)
                } catch {
                    Logger.web3.error(category: "Web3TransferView", message: "Load fee: \(error)")
                }
            }
            if let index = balanceChangeIndex {
                do {
                    try await self.loadBalanceChange(replacingRowAt: index)
                } catch {
                    Logger.web3.error(category: "Web3TransferView", message: "Load bal. change: \(error)")
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
    
}

extension Web3TransferPreviewViewController: Web3PopupViewController {
    
    func reject() {
        operation.reject()
    }
    
}

extension Web3TransferPreviewViewController {
    
    private enum SimulationError: Error {
        case simulationFailure
        case missingApprovalToken
    }
    
    private struct RichBalanceChange {
        
        enum InitError: Error {
            case missingToken(String)
            case invalidAmount(String)
        }
        
        let token: Web3TokenItem
        let amount: Decimal
        
        static func changes(
            from changes: [BalanceChange],
            walletID: String
        ) throws -> [RichBalanceChange] {
            try changes.map { change in
                guard let token = Web3TokenDAO.shared.token(walletID: walletID, assetID: change.assetID) else {
                    throw InitError.missingToken(change.assetID)
                }
                guard let amount = Decimal(string: change.amount, locale: .enUSPOSIX) else {
                    throw InitError.invalidAmount(change.amount)
                }
                return RichBalanceChange(token: token, amount: amount)
            }
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
            layoutTableHeaderView(
                title: R.string.localizable.sending_success(),
                subtitle: R.string.localizable.web3_signing_data_success()
            )
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
    
    private func loadFee(replacingRowAt index: Int) async throws {
        let fee = try await operation.loadFee()
        let feeValue = CurrencyFormatter.localizedString(
            from: fee.token,
            format: .precision,
            sign: .never,
            symbol: nil
        )
        let feeCost = if fee.fiatMoney >= 0.01 {
            CurrencyFormatter.localizedString(
                from: fee.fiatMoney,
                format: .fiatMoney,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            "<" + CurrencyFormatter.localizedString(
                from: 0.01,
                format: .fiatMoney,
                sign: .never,
                symbol: .currencySymbol
            )
        }
        let row: Row = .amount(
            caption: .fee,
            token: feeValue + " " + operation.feeToken.symbol,
            fiatMoney: feeCost,
            display: .byToken,
            boldPrimaryAmount: false
        )
        await MainActor.run {
            self.replaceRow(at: index, with: row)
        }
    }
    
    private func loadBalanceChange(replacingRowAt index: Int) async throws {
        let row: Row
        let simulation = try await operation.simulateTransaction()
        if let approve = simulation.approves?.first {
            let token = Web3TokenDAO.shared.token(
                walletID: operation.walletID,
                assetID: approve.assetID
            )
            guard let token else {
                throw SimulationError.missingApprovalToken
            }
            switch approve.amount {
            case .unlimited:
                row = .web3Amount(
                    caption: R.string.localizable.preauthorize_amount(),
                    tokenAmount: nil,
                    fiatMoneyAmount: nil,
                    token: token
                )
            case .limited(let value):
                let tokenAmount = CurrencyFormatter.localizedString(
                    from: value,
                    format: .precision,
                    sign: .never
                )
                let fiatMoneyAmount = CurrencyFormatter.localizedString(
                    from: value * token.decimalUSDPrice * Currency.current.decimalRate,
                    format: .fiatMoney,
                    sign: .never,
                    symbol: .currencySymbol
                )
                row = .web3Amount(
                    caption: R.string.localizable.preauthorize_amount(),
                    tokenAmount: tokenAmount,
                    fiatMoneyAmount: fiatMoneyAmount,
                    token: token
                )
            }
        } else if !simulation.balanceChanges.isEmpty {
            let changes = try RichBalanceChange.changes(
                from: simulation.balanceChanges,
                walletID: operation.walletID
            )
            if changes.count == 1 {
                let amount = changes[0].amount
                let token = changes[0].token
                let tokenAmount = CurrencyFormatter.localizedString(
                    from: amount,
                    format: .precision,
                    sign: .never
                )
                let fiatMoneyAmount = CurrencyFormatter.localizedString(
                    from: amount * token.decimalUSDPrice * Currency.current.decimalRate,
                    format: .fiatMoney,
                    sign: .never,
                    symbol: .currencySymbol
                )
                row = .web3Amount(
                    caption: R.string.localizable.estimated_balance_change(),
                    tokenAmount: tokenAmount,
                    fiatMoneyAmount: fiatMoneyAmount,
                    token: token
                )
            } else {
                let localizedChanges = changes.map { change in
                    let amount = CurrencyFormatter.localizedString(
                        from: change.amount,
                        format: .precision,
                        sign: .always,
                        symbol: .custom(change.token.symbol)
                    )
                    return (token: change.token, amount: amount)
                }
                row = .assetChanges(localizedChanges)
            }
        } else {
            throw SimulationError.simulationFailure
        }
        await MainActor.run {
            self.replaceRow(at: index, with: row)
        }
    }
    
}
