import UIKit
import web3
import MixinServices

final class Web3TransferInputAmountViewController: FeeRequiredInputAmountViewController {
    
    private let payment: Web3SendingTokenToAddressPayment
    
    private var fee: Web3TransferOperation.DisplayFee?
    private var feeToken: Web3TokenItem?
    private var minimumTransferAmount: Decimal?
    
    init(payment: Web3SendingTokenToAddressPayment) {
        self.payment = payment
        let token = payment.token
        super.init(token: token, precision: token.precision)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.send_to_title()
        switch payment.toAddressLabel {
        case let .addressBook(label):
            let titleView = NavigationTitleView(title: R.string.localizable.send_to_title())
            titleView.subtitle = label
            titleView.subtitleStyle = .label(backgroundColor: R.color.address_label()!)
            navigationItem.titleView = titleView
        case let .wallet(wallet):
            switch wallet {
            case .privacy:
                navigationItem.titleView = WalletIdentifyingNavigationTitleView(
                    title: R.string.localizable.send_to_title(),
                    wallet: .privacy
                )
            case .common(let wallet):
                let titleView = NavigationTitleView(title: R.string.localizable.send_to_title())
                titleView.subtitle = wallet.name
                titleView.subtitleStyle = .label(backgroundColor: R.color.wallet_label()!)
                navigationItem.titleView = titleView
            }
        case let .contact(user):
            navigationItem.titleView = UserNavigationTitleView(
                title: R.string.localizable.send_to_title(),
                user: user
            )
        case .none:
            let titleView = NavigationTitleView(title: R.string.localizable.send_to_title())
            titleView.subtitle = payment.toAddressCompactRepresentation
            titleView.subtitleStyle = .plain
            navigationItem.titleView = titleView
        }
        tokenIconView.setIcon(web3Token: payment.token)
        tokenNameLabel.text = payment.token.name
        tokenBalanceLabel.text = payment.token.localizedBalanceWithSymbol
        addFeeView()
        reloadFee(payment: payment)
        reloadMinimumTransferAmount(payment: payment)
    }
    
    override func review(_ sender: Any) {
        let amount = tokenAmount
        reviewButton.isEnabled = false
        reviewButton.isBusy = true
        DispatchQueue.global().async { [payment] in
            let initError: Error?
            do {
                let operation = switch payment.chain.specification {
                case .evm(let chainID):
                    try EVMTransferToAddressOperation(
                        evmChainID: chainID,
                        payment: payment,
                        decimalAmount: amount
                    )
                case .solana:
                    try SolanaTransferToAddressOperation(payment: payment, decimalAmount: amount)
                }
                DispatchQueue.main.async {
                    let transfer = Web3TransferPreviewViewController(
                        operation: operation,
                        proposer: .user(toAddressLabel: payment.toAddressLabel),
                    )
                    transfer.manipulateNavigationStackOnFinished = true
                    Web3PopupCoordinator.enqueue(popup: .request(transfer))
                }
                initError = nil
            } catch {
                initError = error
            }
            DispatchQueue.main.async {
                if let initError {
                    showAutoHiddenHud(style: .error, text: "\(initError)")
                }
                self.reviewButton.isEnabled = true
                self.reviewButton.isBusy = false
            }
        }
    }
    
    override func addFee(_ sender: Any) {
        guard let feeToken else {
            return
        }
        let selector = AddTokenMethodSelectorViewController(token: feeToken)
        selector.delegate = self
        present(selector, animated: true)
    }
    
    override func inputMultipliedAmount(_ sender: UIButton) {
        guard let fee else {
            return
        }
        let multiplier = self.multiplier(tag: sender.tag)
        if payment.sendingNativeToken {
            let availableBalance = max(0, token.decimalBalance - fee.tokenAmount)
            replaceAmount(availableBalance * multiplier)
        } else {
            replaceAmount(token.decimalBalance * multiplier)
        }
    }
    
    override func reloadViewsWithBalanceRequirements() {
        guard let fee, let feeToken, let minimumTransferAmount else {
            insufficientBalanceLabel.text = nil
            reviewButton.isEnabled = false
            return
        }
        guard tokenAmount.isZero || tokenAmount >= minimumTransferAmount else {
            insufficientBalanceLabel.text = R.string.localizable.send_sol_for_rent(
                CurrencyFormatter.localizedString(
                    from: minimumTransferAmount,
                    format: .precision,
                    sign: .never
                )
            )
            removeAddFeeButton()
            reviewButton.isEnabled = false
            return
        }
        let feeRequirement = BalanceRequirement(token: feeToken, amount: fee.tokenAmount)
        let requirements = inputAmountRequirement.merging(with: feeRequirement)
        if requirements.allSatisfy(\.isSufficient) {
            insufficientBalanceLabel.text = nil
            removeAddFeeButton()
            reviewButton.isEnabled = tokenAmount > 0
        } else {
            let bothRequirementsInsufficient = (requirements.count == 1 && tokenAmount != 0)
            || (!inputAmountRequirement.isSufficient && !feeRequirement.isSufficient)
            if bothRequirementsInsufficient {
                insufficientBalanceLabel.text = R.string.localizable.insufficient_balance()
                addAddFeeButton(symbol: feeRequirement.token.symbol)
            } else if !inputAmountRequirement.isSufficient {
                insufficientBalanceLabel.text = R.string.localizable.insufficient_balance()
                removeAddFeeButton()
            } else {
                insufficientBalanceLabel.text = R.string.localizable.web3_transfer_insufficient_fee_count(
                    feeRequirement.localizedAmountWithSymbol,
                    feeRequirement.token.localizedBalanceWithSymbol
                )
                addAddFeeButton(symbol: feeRequirement.token.symbol)
            }
            reviewButton.isEnabled = false
        }
    }
    
    private func reloadFee(payment: Web3SendingTokenToAddressPayment) {
        Task {
            do {
                let operation = switch payment.chain.specification {
                case .evm(let chainID):
                    try EVMTransferToAddressOperation(
                        evmChainID: chainID,
                        payment: payment,
                        decimalAmount: 0
                    )
                case .solana:
                    try SolanaTransferToAddressOperation(payment: payment, decimalAmount: 0)
                }
                let fee = try await operation.loadFee()
                let feeToken = operation.feeToken
                let title = CurrencyFormatter.localizedString(
                    from: fee.tokenAmount,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(feeToken.symbol)
                )
                let availableBalance = if payment.sendingNativeToken {
                    CurrencyFormatter.localizedString(
                        from: max(0, payment.token.decimalBalance - fee.tokenAmount),
                        format: .precision,
                        sign: .never,
                        symbol: .custom(feeToken.symbol)
                    )
                } else {
                    payment.token.localizedBalanceWithSymbol
                }
                await MainActor.run {
                    self.fee = fee
                    self.feeToken = feeToken
                    self.feeActivityIndicator?.stopAnimating()
                    self.tokenBalanceLabel.text = R.string.localizable.available_balance_count(availableBalance)
                    if let button = self.changeFeeButton {
                        button.configuration?.attributedTitle = AttributedString(title, attributes: feeAttributes)
                        button.alpha = 1
                        button.configuration?.image = nil
                        button.isUserInteractionEnabled = false
                    }
                    if self.minimumTransferAmount != nil {
                        self.reviewButton.isBusy = false
                        self.reloadViewsWithBalanceRequirements()
                    }
                }
            } catch MixinAPIResponseError.unauthorized {
                return
            } catch {
                Logger.general.debug(category: "Web3InputAmount", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    // Check token and address
                    self?.reloadFee(payment: payment)
                }
            }
        }
    }
    
    private func reloadMinimumTransferAmount(payment: Web3SendingTokenToAddressPayment) {
        // Only SOL transfers invoke minimum amount checking
        // Review `balanceSufficiency` if it involves EVM transfers
        Task {
            do {
                let amount: Decimal
                switch payment.chain.kind {
                case .evm:
                    amount = 0
                case .solana:
                    if payment.sendingNativeToken {
                        let accountExists = try await RouteAPI.solanaAccountExists(pubkey: payment.toAddress)
                        amount = accountExists ? 0 : Solana.accountCreationCost
                    } else {
                        amount = 0
                    }
                }
                await MainActor.run {
                    self.minimumTransferAmount = amount
                    if self.fee != nil {
                        self.reviewButton.isBusy = false
                        self.reloadViewsWithBalanceRequirements()
                    }
                }
            } catch MixinAPIResponseError.unauthorized {
                return
            } catch {
                Logger.general.debug(category: "Web3InputAmount", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.reloadMinimumTransferAmount(payment: payment)
                }
            }
        }
    }
    
}

extension Web3TransferInputAmountViewController: AddTokenMethodSelectorViewController.Delegate {
    
    func addTokenMethodSelectorViewController(
        _ viewController: AddTokenMethodSelectorViewController,
        didPickMethod method: AddTokenMethodSelectorViewController.Method
    ) {
        guard let feeToken else {
            return
        }
        let next: UIViewController
        switch method {
        case .swap:
            next = Web3SwapViewController(
                wallet: payment.wallet,
                sendAssetID: nil,
                receiveAssetID: feeToken.assetID,
            )
        case .deposit:
            next = DepositViewController(wallet: payment.wallet, token: feeToken)
        }
        navigationController?.pushViewController(next, animated: true)
    }
    
}
