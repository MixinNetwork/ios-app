import UIKit
import MixinServices

final class InsufficientBalanceViewController: AuthenticationPreviewViewController {
    
    enum Intent {
        case privacyWalletTransfer(BalanceRequirement)
        case withdraw(withdrawing: BalanceRequirement, fee: BalanceRequirement)
        case commonWalletTransfer(transferring: BalanceRequirement, fee: BalanceRequirement)
    }
    
    private let intent: Intent
    private let insufficientToken: any (ValuableToken & OnChainToken)
    private let stablecoinAssetIDs: Set<String> = [
        AssetID.erc20USDT, AssetID.tronUSDT, AssetID.eosUSDT,
        AssetID.polygonUSDT, AssetID.bep20USDT, AssetID.solanaUSDT,
        AssetID.erc20USDC, AssetID.solanaUSDC, AssetID.baseUSDC,
        AssetID.polygonUSDC, AssetID.bep20USDC,
    ]
    
    private var swappingFromAssetID: String?
    
    init(intent: Intent) {
        self.intent = intent
        self.insufficientToken = switch intent {
        case let .privacyWalletTransfer(requirement):
            requirement.token
        case let .withdraw(primary, fee), let .commonWalletTransfer(primary, fee):
            if !primary.isSufficient {
                primary.token
            } else {
                fee.token
            }
        }
        super.init(warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.backgroundColor = R.color.background_quaternary()
        tableHeaderView.style = .insetted
        tableHeaderView.setIcon(token: insufficientToken)
        let title = R.string.localizable.insufficient_balance_symbol(insufficientToken.symbol)
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
            } else if !withdrawing.isSufficient {
                R.string.localizable.withdraw_insufficient_balance_count(
                    withdrawing.localizedAmountWithSymbol,
                    withdrawing.token.localizedBalanceWithSymbol,
                )
            } else {
                R.string.localizable.withdraw_insufficient_fee_count(
                    fee.localizedAmountWithSymbol,
                    fee.token.localizedBalanceWithSymbol,
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
            } else if !transferring.isSufficient {
                R.string.localizable.transfer_insufficient_balance_count(
                    transferring.localizedAmountWithSymbol,
                    transferring.token.localizedBalanceWithSymbol,
                )
            } else {
                R.string.localizable.transfer_insufficient_fee_count(
                    fee.localizedAmountWithSymbol,
                    fee.token.localizedBalanceWithSymbol,
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
                        token: insufficientToken.localizedBalanceWithSymbol,
                        fiatMoney: insufficientToken.localizedFiatMoneyBalance,
                        display: .byToken,
                        boldPrimaryAmount: false
                    )
                )
            }
        }
        
        rows.append(
            .info(
                caption: .network,
                content: insufficientToken.depositNetworkName ?? ""
            )
        )
        
        reloadData(with: rows)
        
        if stablecoinAssetIDs.contains(insufficientToken.assetID) {
            let currentToken = insufficientToken
            DispatchQueue.global().async { [intent, stablecoinAssetIDs, weak self] in
                let assetIDs = stablecoinAssetIDs.subtracting([currentToken.assetID])
                let mostValuableStablecoin: (any ValuableToken)? = switch intent {
                case .privacyWalletTransfer, .withdraw:
                    TokenDAO.shared.greatestBalanceToken(assetIDs: assetIDs)
                case .commonWalletTransfer:
                    if let walletID = (currentToken as? Web3TokenItem)?.walletID {
                        Web3TokenDAO.shared.greatestBalanceToken(walletID: walletID, assetIDs: assetIDs)
                    } else {
                        nil
                    }
                }
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    if let mostValuableStablecoin {
                        self.swappingFromAssetID = mostValuableStablecoin.assetID
                        self.loadSwapUSDTView()
                    } else {
                        self.loadActionsTrayView()
                    }
                }
            }
        } else {
            loadActionsTrayView()
        }
    }
    
    override func loadTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
    }
    
    override func loadInitialTrayView(animated: Bool) {
        // Don't load default tray view
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        switch cell {
        case let cell as AuthenticationPreviewInfoCell:
            if indexPath.row == 0 {
                cell.contentTopConstraint.constant = 20
            }
            cell.contentLeadingConstraint.constant = 16
            cell.contentTrailingConstraint.constant = 16
        case let cell as AuthenticationPreviewCompactInfoCell:
            if indexPath.row == rows.count - 1 {
                cell.contentBottomConstraint.constant = 20
            }
            cell.contentLeadingConstraint.constant = 16
            cell.contentTrailingConstraint.constant = 16
        default:
            break
        }
        return cell
    }
    
    @objc private func loadActionsTrayView() {
        loadDoubleButtonTrayView(
            leftTitle: R.string.localizable.cancel(),
            leftAction: #selector(close(_:)),
            rightTitle: R.string.localizable.add_token(insufficientToken.symbol),
            rightAction: #selector(addToken(_:)),
            animation: trayView == nil ? .none : .vertical
        )
        trayView?.backgroundColor = R.color.background_quaternary()
    }
    
    @objc private func addToken(_ sender: Any) {
        let selector = AddTokenMethodSelectorViewController(token: insufficientToken)
        selector.delegate = self
        present(selector, animated: true)
    }
    
    @objc private func swap(_ sender: Any) {
        guard let from = swappingFromAssetID else {
            return
        }
        let to = insufficientToken.assetID
        let swap: UIViewController
        switch intent {
        case .privacyWalletTransfer, .withdraw:
            swap = MixinSwapViewController(
                sendAssetID: from,
                receiveAssetID: to,
                referral: nil
            )
        case .commonWalletTransfer:
            guard let walletID = (insufficientToken as? Web3TokenItem)?.walletID else {
                return
            }
            swap = Web3SwapViewController(
                sendAssetID: from,
                receiveAssetID: to,
                walletID: walletID
            )
        }
        presentingViewController?.dismiss(animated: true) {
            UIApplication.homeNavigationController?.pushViewController(swap, animated: true)
        }
    }
    
    private func loadSwapUSDTView() {
        loadDialogTrayView(animation: .vertical) { view in
            view.backgroundColor = R.color.background_quaternary()
            view.iconImageView.image = R.image.ic_warning()?.withRenderingMode(.alwaysTemplate)
            view.titleLabel.text = R.string.localizable.swap_usdt_hint()
            view.leftButton.setTitle(R.string.localizable.cancel(), for: .normal)
            view.leftButton.addTarget(self, action: #selector(loadActionsTrayView), for: .touchUpInside)
            view.rightButton.setTitle(R.string.localizable.swap(), for: .normal)
            view.rightButton.addTarget(self, action: #selector(swap(_:)), for: .touchUpInside)
            view.style = .yellow
        }
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
