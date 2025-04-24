import UIKit
import web3
import MixinServices

final class Web3TransferInputAmountViewController: InputAmountViewController {
    
    override var balanceSufficiency: BalanceSufficiency {
        guard let fee, let feeToken else {
            return .insufficient(nil)
        }
        let balanceInsufficient = tokenAmount > token.decimalBalance
        let feeInsufficient = if payment.sendingNativeToken {
            tokenAmount > token.decimalBalance - fee.token
        } else {
            false // FIXME: Detemine with feeToken.balance
        }
        if balanceInsufficient {
            return .insufficient(R.string.localizable.insufficient_balance())
        } else if feeInsufficient {
            return .insufficient(
                R.string.localizable.insufficient_fee_description(
                    CurrencyFormatter.localizedString(
                        from: fee.token,
                        format: .precision,
                        sign: .never,
                        symbol: .custom(feeToken.symbol)
                    ),
                    feeToken.chain?.name ?? ""
                )
            )
        } else {
            return .sufficient
        }
    }
    
    private let payment: Web3SendingTokenToAddressPayment
    
    private var fee: Web3TransferOperation.Fee?
    private var feeToken: Web3TokenItem?
    
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
    }
    
    override func review(_ sender: Any) {
        let amount = tokenAmount
        reviewButton.isEnabled = false
        reviewButton.isBusy = true
        let proposer: Web3TransferPreviewViewController.Proposer
        switch payment.toType {
        case .privacyWallet:
            proposer = .web3ToMixinWallet
        case .addressBook, .arbitrary:
            proposer = .web3ToAddress
        }
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
                    let transfer = Web3TransferPreviewViewController(operation: operation, proposer: proposer)
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
    
    override func inputMultipliedAmount(_ sender: UIButton) {
        guard let fee else {
            return
        }
        let multiplier = self.multiplier(tag: sender.tag)
        if payment.sendingNativeToken {
            let availableBalance = max(0, token.decimalBalance - fee.token)
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
                let title = CurrencyFormatter.localizedString(
                    from: fee.token,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(operation.feeToken.symbol)
                )
                let availableBalance = if payment.sendingNativeToken {
                    CurrencyFormatter.localizedString(
                        from: max(0, payment.token.decimalBalance - fee.token),
                        format: .precision,
                        sign: .never,
                        symbol: .custom(operation.feeToken.symbol)
                    )
                } else {
                    payment.token.localizedBalanceWithSymbol
                }
                await MainActor.run {
                    self.fee = fee
                    self.feeToken = operation.feeToken
                    self.feeActivityIndicator?.stopAnimating()
                    self.reloadViewsWithBalanceSufficiency()
                    self.tokenBalanceLabel.text = R.string.localizable.available_balance(availableBalance)
                    if let button = self.changeFeeButton {
                        button.configuration?.attributedTitle = AttributedString(title, attributes: feeAttributes)
                        button.alpha = 1
                        button.configuration?.image = nil
                        button.isUserInteractionEnabled = false
                    }
                    self.reviewButton.isBusy = false
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
    
}
