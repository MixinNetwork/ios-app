import UIKit
import Combine
import BigInt
import web3
import ReownWalletKit
import MixinServices

final class Web3TransferPreviewViewController: WalletIdentifyingAuthenticationPreviewViewController {
    
    enum Proposer {
        case dapp(Web3DappProposer)
        case user(toAddressLabel: AddressLabel?)
        case speedUp(sender: Web3TransactionViewController)
        case cancel(sender: Web3TransactionViewController)
    }
    
    var manipulateNavigationStackOnFinished = false
    
    private let operation: Web3TransferOperation
    private let proposer: Proposer?
    
    private var stateObserver: AnyCancellable?
    
    init(operation: Web3TransferOperation, proposer: Proposer?) {
        self.operation = operation
        self.proposer = proposer
        super.init(wallet: .common(operation.wallet), warnings: [])
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
                    case .dapp, .none, .user:
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
        case .dapp, .user, .none:
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
            case .user:
                let subtitle = R.string.localizable.signature_request_from(.mixinMessenger)
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
                if let simulation = operation.hardcodedSimulation {
                    rows = makeRows(simulation: simulation)
                    balanceChangeIndex = nil
                    feeIndex = rows.count
                } else {
                    rows.append(
                        .web3Message(
                            caption: R.string.localizable.estimated_balance_change(),
                            message: R.string.localizable.loading()
                        )
                    )
                    balanceChangeIndex = 0
                    feeIndex = 1
                }
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
        case let .dapp(proposer):
            rows.append(.doubleLineInfo(caption: .from, primary: proposer.name, secondary: proposer.host))
            rows.append(.address(caption: .wallet, address: operation.fromAddress.destination, label: .wallet(.common(operation.wallet))))
        case let .user(toAddressLabel):
            switch toAddressLabel {
            case .wallet(.privacy):
                rows.append(.wallet(caption: .receiver, wallet: .privacy, threshold: nil))
            case .wallet(.safe(let vault)):
                rows.append(.safe(name: vault.name, role: vault.role))
            case .contact(let user):
                if let toAddress = operation.toAddress {
                    rows.append(.commonWalletReceiver(user: user, address: toAddress))
                }
            default:
                if let toAddress = operation.toAddress {
                    rows.append(.address(caption: .receiver, address: toAddress, label: toAddressLabel))
                }
            }
            rows.append(.address(caption: .sender, address: operation.fromAddress.destination, label: .wallet(.common(operation.wallet))))
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
            if operation.hardcodedSimulation == nil, let index = balanceChangeIndex {
                await self.loadBalanceChange(replacingRowAt: index)
            }
        }
        reporter.report(event: .sendPreview)
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
        case .waivedFee:
            let description = CrossWalletTransactionFreeIntroductionViewController()
            present(description, animated: true)
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
    
    private func reloadData(state: Web3TransferOperation.State) {
        var confirmButton: UIButton? {
            (trayView as? AuthenticationPreviewDoubleButtonTrayView)?.rightButton
        }
        
        switch state {
        case .loading:
            confirmButton?.isEnabled = false
        case .unavailable(let reason):
            canDismissInteractively = true
            tableHeaderView.setIcon(progress: .failure)
            layoutTableHeaderView(
                title: R.string.localizable.speed_up_failed(),
                subtitle: reason
            )
            tableView.setContentOffset(.zero, animated: true)
            loadSingleButtonTrayView(
                title: R.string.localizable.done(),
                action: #selector(close(_:))
            )
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
            reporter.report(event: .sendEnd)
            canDismissInteractively = true
            tableHeaderView.setIcon(progress: .success)
            layoutTableHeaderView(
                title: R.string.localizable.sending_success(),
                subtitle: R.string.localizable.web3_signing_data_success()
            )
            tableView.setContentOffset(.zero, animated: true)
            loadSingleButtonTrayView(title: R.string.localizable.done(), action: #selector(close(_:)))
            if manipulateNavigationStackOnFinished,
               let navigationController = UIApplication.homeNavigationController
            {
                switch proposer {
                case let .speedUp(sender), let .cancel(sender):
                    if let viewController = navigationController.viewControllers.last,
                       viewController as? Web3TransactionViewController == sender
                    {
                        navigationController.popViewController(animated: false)
                    }
                default:
                    if let home = navigationController.viewControllers.first {
                        navigationController.setViewControllers([home], animated: false)
                    }
                }
            }
        }
    }
    
    private func loadFee(replacingRowAt index: Int) async throws {
        let fee = try await operation.loadFee()
        var feeValue = CurrencyFormatter.localizedString(
            from: fee.tokenAmount,
            format: .precision,
            sign: .never,
            symbol: .custom(operation.feeToken.symbol)
        )
        if let fee = fee as? EVMTransferOperation.EVMDisplayFee {
            let feePerGas = CurrencyFormatter.localizedString(
                from: fee.feePerGas,
                format: .precision,
                sign: .never,
                symbol: .custom("Gwei")
            )
            feeValue.append(" (\(feePerGas))")
        }
        let feeCost = if fee.fiatMoneyAmount >= 0.01 {
            CurrencyFormatter.localizedString(
                from: fee.fiatMoneyAmount,
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
        let isFeeWaived: Bool = switch proposer {
        case .user(let label):
            label?.isFeeWaived() ?? false
        case .speedUp, .cancel, .dapp, .none:
            false
        }
        let row: Row = if isFeeWaived {
            .waivedFee(
                token: feeValue,
                fiatMoney: feeCost,
                display: .byToken
            )
        } else {
            .amount(
                caption: .fee,
                token: feeValue,
                fiatMoney: feeCost,
                display: .byToken,
                boldPrimaryAmount: false
            )
        }
        await MainActor.run {
            self.replaceRow(at: index, with: row)
        }
    }
    
    private func loadBalanceChange(replacingRowAt index: Int) async {
        let simulationRows: [Row]
        do {
            let simulation = try await operation.simulateTransaction()
            simulationRows = makeRows(simulation: simulation)
        } catch {
            simulationRows = makeRows(simulation: .empty)
        }
        await MainActor.run {
            if let row = simulationRows.first {
                self.replaceRow(at: index, with: row)
            }
            if simulationRows.count == 2 {
                self.insertRow(simulationRows[1], at: index + 1)
            }
        }
    }
    
    private func makeRows(simulation: TransactionSimulation) -> [Row] {
        var rows: [Row] = []
        
        if let approve = simulation.approves?.first {
            let token = Web3TokenDAO.shared.token(
                walletID: operation.wallet.walletID,
                assetID: approve.assetID
            )
            switch approve.amount {
            case .unlimited:
                rows.append(
                    .web3Amount(
                        caption: R.string.localizable.preauthorize_amount(),
                        content: .unlimited,
                        token: token ?? approve,
                        chain: token?.chain
                    )
                )
            case .limited(let value):
                let tokenAmount = CurrencyFormatter.localizedString(
                    from: value,
                    format: .precision,
                    sign: .never
                )
                let fiatMoneyAmount: String? = if let token {
                    CurrencyFormatter.localizedString(
                        from: value * token.decimalUSDPrice * Currency.current.decimalRate,
                        format: .fiatMoney,
                        sign: .never,
                        symbol: .currencySymbol
                    )
                } else {
                    nil
                }
                rows.append(
                    .web3Amount(
                        caption: R.string.localizable.preauthorize_amount(),
                        content: .limited(token: tokenAmount, fiatMoney: fiatMoneyAmount),
                        token: token ?? approve,
                        chain: token?.chain
                    )
                )
            }
        }
        
        let changes = simulation.balanceChanges ?? []
        if changes.count == 1 {
            let amount = Decimal(string: changes[0].amount, locale: .enUSPOSIX)
            let tokenAmount = if let amount {
                CurrencyFormatter.localizedString(
                    from: amount,
                    format: .precision,
                    sign: .never
                )
            } else {
                changes[0].amount
            }
            
            let token = Web3TokenDAO.shared.token(
                walletID: operation.wallet.walletID,
                assetID: changes[0].assetID
            )
            let fiatMoneyAmount: String? = if let token, let amount {
                CurrencyFormatter.localizedString(
                    from: amount * token.decimalUSDPrice * Currency.current.decimalRate,
                    format: .fiatMoney,
                    sign: .never,
                    symbol: .currencySymbol
                )
            } else {
                nil
            }
            rows.append(
                .web3Amount(
                    caption: R.string.localizable.estimated_balance_change(),
                    content: .limited(token: tokenAmount, fiatMoney: fiatMoneyAmount),
                    token: token,
                    chain: token?.chain
                )
            )
        } else if changes.count > 1 {
            let styledChanges: [StyledAssetChange] = changes.map { change in
                let decimalAmount = Decimal(string: change.amount, locale: .enUSPOSIX)
                let amount = if let decimalAmount {
                    CurrencyFormatter.localizedString(
                        from: decimalAmount,
                        format: .precision,
                        sign: .always,
                        symbol: .custom(change.symbol)
                    )
                } else {
                    change.amount
                }
                let style: StyledAssetChange.AmountStyle = if let decimalAmount {
                    if decimalAmount > 0 {
                        .income
                    } else if decimalAmount == 0 {
                        .plain
                    } else {
                        .outcome
                    }
                } else {
                    .plain
                }
                return StyledAssetChange(
                    token: change,
                    amount: amount,
                    amountStyle: style
                )
            }
            rows.append(.assetChanges(estimated: true, changes: styledChanges))
        }
        
        if rows.isEmpty {
            rows.append(
                .web3Amount(
                    caption: R.string.localizable.estimated_balance_change(),
                    content: .decodingFailed,
                    token: nil,
                    chain: nil
                )
            )
        }
        
        return rows
    }
    
}
