import UIKit
import web3
import MixinServices

final class Web3TransferInputAmountViewController: FeeRequiredInputAmountViewController {
    
    private let payment: Web3SendingTokenToAddressPayment
    
    private var fee: Web3DisplayFee?
    private var solanaReceiverAccountExists: Bool?
    
    private var feeCalculatingTask: Task<Void, Error>?
    private var bitcoinFeeCalculator: Bitcoin.P2WPKHFeeCalculator?
    
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
            case .safe(let wallet):
                navigationItem.titleView = WalletIdentifyingNavigationTitleView(
                    title: R.string.localizable.send_to_title(),
                    wallet: .safe(wallet)
                )
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
        switch payment.chain.specification {
        case .bitcoin:
            // Will reload later in `reloadviews(inputAmount:)`
            break
        case .evm, .solana:
            reloadFee(payment: payment, transferAmount: 0)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        feeCalculatingTask?.cancel()
    }
    
    override func reloadViews(inputAmount: Decimal) {
        super.reloadViews(inputAmount: inputAmount)
        switch payment.chain.specification {
        case .bitcoin:
            feeCalculatingTask?.cancel()
            reloadFee(payment: payment, transferAmount: inputAmount)
        case .evm, .solana:
            break
        }
    }
    
    override func review(_ sender: Any) {
        let amount = tokenAmount
        reviewButton.isEnabled = false
        reviewButton.isBusy = true
        DispatchQueue.global().async { [payment] in
            let initError: Error?
            do {
                let operation = switch payment.chain.specification {
                case .bitcoin:
                    try BitcoinTransferToAddressOperation(payment: payment, decimalAmount: amount)
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
        guard let feeToken = fee?.token else {
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
        if let bitcoinFeeCalculator, multiplier == 1 {
            let maxAmount = bitcoinFeeCalculator.exhaustingOutputsTransferAmount()
            replaceAmount(maxAmount)
        } else if payment.sendingNativeToken {
            let availableBalance = switch payment.chain.kind {
            case .bitcoin, .evm:
                token.decimalBalance - fee.tokenAmount
            case .solana:
                token.decimalBalance - fee.tokenAmount - Solana.RentExemptionValue.systemAccount
            }
            replaceAmount(max(0, availableBalance) * multiplier)
        } else {
            replaceAmount(token.decimalBalance * multiplier)
        }
    }
    
    override func reloadViewsWithBalanceRequirements() {
        guard let fee, tokenAmount > 0 else {
            insufficientBalanceLabel.text = nil
            removeAddFeeButton()
            reviewButton.isEnabled = false
            return
        }
        
        enum TransferAmountFailure {
            case solanaRentExemption(Solana.RentExemptionFailedReason)
            case bitcoinDust
        }
        
        let transferAmountFailure: TransferAmountFailure?
        if let accountExists = solanaReceiverAccountExists {
            let reason = if payment.sendingNativeToken {
                Solana.checkRentExemptionForSOLTransfer(
                    sendingAmount: tokenAmount,
                    feeAmount: fee.tokenAmount,
                    senderSOLBalance: payment.token.decimalBalance,
                    receiverAccountExists: accountExists
                )
            } else {
                Solana.checkRentExemptionForSPLTokenTransfer(
                    senderSOLBalance: fee.token.decimalBalance,
                    feeAmount: fee.tokenAmount,
                    receiverAccountExists: accountExists
                )
            }
            if let reason {
                transferAmountFailure = .solanaRentExemption(reason)
            } else {
                transferAmountFailure = nil
            }
        } else if payment.chain == .bitcoin {
            if tokenAmount < Bitcoin.spendingDust {
                transferAmountFailure = .bitcoinDust
            } else {
                transferAmountFailure = nil
            }
        } else {
            transferAmountFailure = nil
        }
        
        let feeRequirement = BalanceRequirement(token: fee.token, amount: fee.tokenAmount)
        let requirements = inputAmountRequirement.merging(with: feeRequirement)
        if requirements.allSatisfy(\.isSufficient) && transferAmountFailure == nil {
            insufficientBalanceLabel.text = nil
            removeAddFeeButton()
            reviewButton.isEnabled = true
        } else if requirements.allSatisfy({ !$0.isSufficient }) {
            insufficientBalanceLabel.text = R.string.localizable.insufficient_balance()
            insertAddFeeButton(symbol: inputAmountRequirement.token.symbol)
            reviewButton.isEnabled = false
        } else if !inputAmountRequirement.isSufficient {
            insufficientBalanceLabel.text = R.string.localizable.insufficient_balance()
            removeAddFeeButton()
            reviewButton.isEnabled = false
        } else if !feeRequirement.isSufficient {
            insufficientBalanceLabel.text = R.string.localizable.web3_transfer_insufficient_fee_count(
                feeRequirement.localizedAmountWithSymbol,
                feeRequirement.token.localizedBalanceWithSymbol
            )
            insertAddFeeButton(symbol: feeRequirement.token.symbol)
            reviewButton.isEnabled = false
        } else if let transferAmountFailure {
            switch transferAmountFailure {
            case let .solanaRentExemption(reason):
                insufficientBalanceLabel.text = reason.localizedDescription
                // Rent-exemption depends only on SOL balance
                // Show "Add SOL" button if insufficient
                insertAddFeeButton(symbol: fee.token.symbol)
            case .bitcoinDust:
                insufficientBalanceLabel.text = R.string.localizable.send_token_minimum_amount(
                    CurrencyFormatter.localizedString(
                        from: Bitcoin.spendingDust,
                        format: .precision,
                        sign: .never,
                        symbol: .custom(payment.token.symbol)
                    )
                )
                removeAddFeeButton()
            }
            reviewButton.isEnabled = false
        }
    }
    
}

extension Web3TransferInputAmountViewController: AddTokenMethodSelectorViewController.Delegate {
    
    func addTokenMethodSelectorViewController(
        _ viewController: AddTokenMethodSelectorViewController,
        didPickMethod method: AddTokenMethodSelectorViewController.Method
    ) {
        guard let feeToken = fee?.token else {
            return
        }
        let next = switch method {
        case .trade:
            TradeViewController(
                wallet: .common(payment.wallet),
                trading: .simpleSpot,
                sendAssetID: nil,
                receiveAssetID: feeToken.assetID,
                referral: nil
            )
        case .deposit:
            DepositViewController(
                wallet: payment.wallet,
                token: feeToken,
                switchingBetweenNetworks: false
            )
        }
        if let next {
            navigationController?.pushViewController(next, animated: true)
        }
    }
    
}

extension Web3TransferInputAmountViewController {
    
    private enum FeeEstimationError: Error {
        case missingFeeToken(String)
    }
    
    @MainActor
    private func reloadFee(
        payment: Web3SendingTokenToAddressPayment,
        transferAmount: Decimal,
    ) {
        let bitcoinFeeCalculator = self.bitcoinFeeCalculator
        feeCalculatingTask = Task {
            do {
                let fee: Web3DisplayFee
                let solanaReceiverAccountExists: Bool?
                switch payment.chain.specification {
                case .bitcoin:
                    let feeToken = try payment.chain.feeToken(
                        walletID: payment.wallet.walletID
                    )
                    guard let feeToken else {
                        throw FeeEstimationError.missingFeeToken(payment.chain.feeTokenAssetID)
                    }
                    let outputs = Web3OutputDAO.shared.outputs(
                        address: payment.fromAddress.destination,
                        assetID: payment.token.assetID,
                        status: [.unspent, .pending]
                    )
                    let calculator: Bitcoin.P2WPKHFeeCalculator
                    if let bitcoinFeeCalculator {
                        calculator = bitcoinFeeCalculator
                    } else {
                        let info = try await RouteAPI.bitcoinNetworkInfo(feeRate: nil)
                        calculator = Bitcoin.P2WPKHFeeCalculator(
                            outputs: outputs,
                            rate: info.decimalFeeRate,
                            minimum: info.minimalFee,
                        )
                        await MainActor.run {
                            self.bitcoinFeeCalculator = calculator
                        }
                    }
                    do {
                        let feeResult = try calculator.calculate(
                            transferAmount: transferAmount == 0 ? 1 * .satoshi : transferAmount
                        )
                        fee = Web3DisplayFee(token: feeToken, amount: feeResult.feeAmount)
                    } catch Bitcoin.P2WPKHFeeCalculator.CalculateError.insufficientOutputs(let feeAmount) {
                        fee = Web3DisplayFee(token: feeToken, amount: feeAmount)
                    } catch {
                        throw error
                    }
                    solanaReceiverAccountExists = nil
                case .evm(let chainID):
                    let operation = try EVMTransferToAddressOperation(
                        evmChainID: chainID,
                        payment: payment,
                        decimalAmount: 0
                    )
                    fee = try await operation.loadFee()
                    solanaReceiverAccountExists = nil
                case .solana:
                    let operation = try SolanaTransferToAddressOperation(
                        payment: payment,
                        decimalAmount: 0
                    )
                    fee = try await operation.loadFee()
                    solanaReceiverAccountExists = operation.receiverAccountExists
                }
                let title = CurrencyFormatter.localizedString(
                    from: fee.tokenAmount,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(fee.token.symbol)
                )
                let availableBalance: String
                if payment.sendingNativeToken {
                    let amount = switch payment.chain.kind {
                    case .bitcoin, .evm:
                        payment.token.decimalBalance - fee.tokenAmount
                    case .solana:
                        payment.token.decimalBalance - fee.tokenAmount - Solana.RentExemptionValue.systemAccount
                    }
                    availableBalance = CurrencyFormatter.localizedString(
                        from: max(0, amount),
                        format: .precision,
                        sign: .never,
                        symbol: .custom(fee.token.symbol)
                    )
                } else {
                    availableBalance = payment.token.localizedBalanceWithSymbol
                }
                let isFeeWaived = payment.toAddressLabel?.isFeeWaived() ?? false
                await MainActor.run {
                    self.fee = fee
                    self.solanaReceiverAccountExists = solanaReceiverAccountExists
                    self.feeActivityIndicator?.stopAnimating()
                    self.tokenBalanceLabel.text = R.string.localizable.available_balance_count(availableBalance)
                    self.updateFeeView(style: isFeeWaived ? .waived : .normal)
                    if let button = self.changeFeeButton {
                        button.configuration?.title = title
                        button.alpha = 1
                        button.configuration?.image = nil
                        button.isUserInteractionEnabled = false
                    }
                    self.reviewButton.isBusy = false
                    self.reloadViewsWithBalanceRequirements()
                }
            } catch MixinAPIResponseError.unauthorized {
                return
            } catch {
                Logger.general.debug(category: "Web3InputAmount", message: "\(error)")
                try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
                DispatchQueue.main.async { [weak self] in
                    self?.reloadFee(payment: payment, transferAmount: transferAmount)
                }
            }
        }
    }
    
}
