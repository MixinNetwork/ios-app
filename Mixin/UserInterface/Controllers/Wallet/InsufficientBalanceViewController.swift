import UIKit
import MixinServices

final class InsufficientBalanceViewController: AuthenticationPreviewViewController {
    
    enum Intent {
        case privacyWalletTransfer(BalanceRequirement)
        case withdraw(withdrawing: BalanceRequirement, fee: BalanceRequirement)
        case commonWalletTransfer(transferring: BalanceRequirement, fee: BalanceRequirement)
    }
    
    private let intent: Intent
    
    private var insufficientToken: any (ValuableToken & OnChainToken) {
        switch intent {
        case let .privacyWalletTransfer(requirement):
            requirement.token
        case let .withdraw(primary, fee), let .commonWalletTransfer(primary, fee):
            if !primary.isSufficient {
                primary.token
            } else {
                fee.token
            }
        }
    }
    
    init(intent: Intent) {
        self.intent = intent
        super.init(warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let token = self.insufficientToken
        
        tableHeaderView.setIcon(token: token)
        let title = R.string.localizable.insufficient_balance_symbol(token.symbol)
        let subtitle: String
        switch intent {
        case let .privacyWalletTransfer(requirement):
            subtitle = R.string.localizable.transfer_insufficient_balance_count(
                requirement.localizedAmountWithSymbol,
                requirement.token.localizedBalanceWithSymbol,
            )
        case let .withdraw(withdrawing, fee):
            let sameToken = withdrawing.token.assetID == fee.token.assetID
            subtitle = if sameToken {
                R.string.localizable.withdraw_aggregated_insufficient_balance_count(
                    withdrawing.localizedAmountWithSymbol,
                    fee.localizedAmountWithSymbol,
                    fee.token.localizedBalanceWithSymbol,
                )
            } else if !fee.isSufficient {
                R.string.localizable.withdraw_insufficient_fee_count(
                    fee.localizedAmountWithSymbol,
                    fee.token.localizedBalanceWithSymbol,
                )
            } else {
                R.string.localizable.withdraw_insufficient_balance_count(
                    withdrawing.localizedAmountWithSymbol,
                    withdrawing.token.localizedBalanceWithSymbol,
                )
            }
        case let .commonWalletTransfer(transferring, fee):
            let sameToken = transferring.token.assetID == fee.token.assetID
            subtitle = if sameToken {
                R.string.localizable.transfer_aggregated_insufficient_balance_count(
                    transferring.localizedAmountWithSymbol,
                    fee.localizedAmountWithSymbol,
                    fee.token.localizedBalanceWithSymbol,
                )
            } else if !fee.isSufficient {
                R.string.localizable.transfer_insufficient_fee_count(
                    fee.localizedAmountWithSymbol,
                    fee.token.localizedBalanceWithSymbol,
                )
            } else {
                R.string.localizable.transfer_insufficient_balance_count(
                    transferring.localizedAmountWithSymbol,
                    transferring.token.localizedBalanceWithSymbol,
                )
            }
        }
        layoutTableHeaderView(title: title, subtitle: subtitle)
        tableHeaderView.titleLabel.textColor = R.color.red()
        tableHeaderView.subtitleLabel.textColor = R.color.red()
        
        var rows: [Row]
        switch intent {
        case let .privacyWalletTransfer(requirement):
            rows = [
                .amount(
                    caption: .amount,
                    token: requirement.localizedAmountWithSymbol,
                    fiatMoney: requirement.localizedFiatMoneyAmountWithSymbol,
                    display: .byToken,
                    boldPrimaryAmount: true
                ),
            ]
        case let .withdraw(primary, fee), let .commonWalletTransfer(primary, fee):
            rows = [
                .amount(
                    caption: .amount,
                    token: primary.localizedAmountWithSymbol,
                    fiatMoney: primary.localizedFiatMoneyAmountWithSymbol,
                    display: .byToken,
                    boldPrimaryAmount: true
                ),
                .amount(
                    caption: .fee,
                    token: fee.localizedAmountWithSymbol,
                    fiatMoney: fee.localizedFiatMoneyAmountWithSymbol,
                    display: .byToken,
                    boldPrimaryAmount: true
                ),
            ]
        }
        
        switch intent {
        case let .privacyWalletTransfer(requirement):
            rows.append(
                .amount(
                    caption: .availableBalance,
                    token: requirement.token.localizedBalanceWithSymbol,
                    fiatMoney: requirement.token.localizedFiatMoneyBalance,
                    display: .byToken,
                    boldPrimaryAmount: false
                )
            )
        case let .withdraw(primary, fee), let .commonWalletTransfer(primary, fee):
            let requirements = primary.merging(with: fee)
            if requirements.count == 1, let total = requirements.first {
                rows.append(contentsOf: [
                    .amount(
                        caption: .total,
                        token: total.localizedAmountWithSymbol,
                        fiatMoney: total.localizedFiatMoneyAmountWithSymbol,
                        display: .byToken,
                        boldPrimaryAmount: false
                    ),
                    .amount(
                        caption: .availableBalance,
                        token: total.token.localizedBalanceWithSymbol,
                        fiatMoney: total.token.localizedFiatMoneyBalance,
                        display: .byToken,
                        boldPrimaryAmount: false
                    ),
                ])
            } else {
                rows.append(
                    .amount(
                        caption: .availableBalance,
                        token: token.localizedBalanceWithSymbol,
                        fiatMoney: token.localizedFiatMoneyBalance,
                        display: .byToken,
                        boldPrimaryAmount: false
                    )
                )
            }
        }
        
        rows.append(
            .info(
                caption: .network,
                content: token.depositNetworkName ?? ""
            )
        )
        
        reloadData(with: rows)
        
        loadDoubleButtonTrayView(
            leftTitle: R.string.localizable.cancel(),
            leftAction: #selector(close(_:)),
            rightTitle: R.string.localizable.add_token(token.symbol),
            rightAction: #selector(addToken(_:)),
            animation: nil
        )
    }
    
    override func loadInitialTrayView(animated: Bool) {
        // Don't load default tray view
    }
    
    @objc private func addToken(_ sender: Any) {
        let selector = AddTokenMethodSelectorViewController(token: insufficientToken)
        selector.delegate = self
        present(selector, animated: true)
    }
    
}

extension InsufficientBalanceViewController: AddTokenMethodSelectorViewController.Delegate {
    
    func addTokenMethodSelectorViewController(
        _ viewController: AddTokenMethodSelectorViewController,
        didPickMethod method: AddTokenMethodSelectorViewController.Method
    ) {
        let next: UIViewController
        switch insufficientToken {
        case let token as MixinTokenItem:
            next = switch method {
            case .swap:
                MixinSwapViewController(
                    sendAssetID: nil,
                    receiveAssetID: token.assetID,
                    referral: nil
                )
            case .deposit:
                DepositViewController(token: token)
            }
        case let token as Web3TokenItem:
            switch method {
            case .swap:
                next = Web3SwapViewController(
                    sendAssetID: nil,
                    receiveAssetID: token.assetID,
                    walletID: token.walletID
                )
            case .deposit:
                guard let address = Web3AddressDAO.shared.address(walletID: token.walletID, chainID: token.chainID) else {
                    return
                }
                guard let kind = Web3Chain.chain(chainID: token.chainID)?.kind else {
                    return
                }
                next = Web3DepositViewController(kind: kind, address: address.destination)
            }
        default:
            return
        }
        presentingViewController?.dismiss(animated: true) {
            UIApplication.homeNavigationController?.pushViewController(next, animated: true)
        }
    }
    
}
