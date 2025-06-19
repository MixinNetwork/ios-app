import UIKit
import web3
import MixinServices

final class Web3TransferInputAmountViewController: InputAmountViewController {
    
    override var balanceSufficiency: BalanceSufficiency {
        guard let fee, let feeToken, let minimumTransferAmount else {
            return .insufficient(nil)
        }
        let balanceInsufficient = tokenAmount > token.decimalBalance
        let feeInsufficient = isFeeInsufficient(fee: fee, feeToken: feeToken)
        return if balanceInsufficient {
            .insufficient(R.string.localizable.insufficient_balance())
        } else if feeInsufficient {
            .insufficient(
                R.string.localizable.insufficient_fee_description(
                    CurrencyFormatter.localizedString(
                        from: fee.amount,
                        format: .precision,
                        sign: .never,
                        symbol: .custom(feeToken.symbol)
                    ),
                    feeToken.chain?.name ?? ""
                )
            )
        } else if !tokenAmount.isZero && tokenAmount < minimumTransferAmount {
            // Only SOL transfers invoke minimum amount checking
            // Change the description when it comes to EVM transfers
            .insufficient(
                R.string.localizable.send_sol_for_rent(
                    CurrencyFormatter.localizedString(
                        from: Solana.accountCreationCost,
                        format: .precision,
                        sign: .never,
                    )
                )
            )
        } else {
            .sufficient
        }
    }
    
    private let payment: Web3SendingTokenToAddressPayment
    
    private var fee: Web3TransferOperation.Fee?
    private var feeToken: Web3TokenItem?
    private var minimumTransferAmount: Decimal?
    
    init(payment: Web3SendingTokenToAddressPayment) {
        self.payment = payment
        let token = payment.token
        super.init(token: token, precision: Int(token.precision))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let titleView = NavigationTitleView(title: R.string.localizable.send_to_title())
        switch payment.toType {
        case .privacyWallet:
            titleView.subtitle = R.string.localizable.privacy_wallet()
            titleView.subtitleStyle = .label(backgroundColor: R.color.wallet_label()!)
        case .addressBook(let label):
            titleView.subtitle = label
            titleView.subtitleStyle = .label(backgroundColor: R.color.address_label()!)
        case .arbitrary:
            titleView.subtitle = payment.toAddressCompactRepresentation
            titleView.subtitleStyle = .plain
        }
        navigationItem.titleView = titleView
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
                        proposer: .user(addressLabel: payment.toType.addressLabel)
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
            let availableBalance = max(0, token.decimalBalance - fee.amount)
            replaceAmount(availableBalance * multiplier)
        } else {
            replaceAmount(token.decimalBalance * multiplier)
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
                    from: fee.amount,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(feeToken.symbol)
                )
                let availableBalance = if payment.sendingNativeToken {
                    CurrencyFormatter.localizedString(
                        from: max(0, payment.token.decimalBalance - fee.amount),
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
                        self.reloadViewsWithBalanceSufficiency()
                    }
                    if self.isFeeInsufficient(fee: fee, feeToken: feeToken) {
                        self.addAddFeeButton(symbol: feeToken.symbol)
                    } else {
                        self.removeAddFeeButton()
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
                        self.reloadViewsWithBalanceSufficiency()
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
    
    private func isFeeInsufficient(
        fee: Web3TransferOperation.Fee,
        feeToken: Web3TokenItem,
    ) -> Bool {
        if payment.sendingNativeToken {
           tokenAmount > token.decimalBalance - fee.amount
       } else {
           fee.amount > feeToken.decimalBalance
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
                sendAssetID: nil,
                receiveAssetID: feeToken.assetID,
                walletID: feeToken.walletID
            )
        case .deposit:
            guard let address = Web3AddressDAO.shared.address(walletID: feeToken.walletID, chainID: feeToken.chainID) else {
                return
            }
            next = Web3DepositViewController(kind: payment.chain.kind, address: address.destination)
        }
        navigationController?.pushViewController(next, animated: true)
    }
    
}
