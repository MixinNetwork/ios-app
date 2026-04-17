import UIKit
import web3
import MixinServices

final class Web3TransferInputAmountViewController: FeeRequiredInputAmountViewController {
    
    private let payment: Web3SendingTokenToAddressPayment
    
    private var feeCalculatingTask: Task<Void, Error>?
    private var fee: Web3TransferOperation.Fee?
    private var bitcoinFeeCalculator: Bitcoin.P2WPKHFeeCalculator?
    private var solanaFeeCalculatingOperation: SolanaTransferToAddressOperation?
    
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
        Task { [payment, solanaFeeCalculatingOperation, fee] in
            let initError: Error?
            do {
                let operation: Web3TransferOperation
                switch payment.chain.specification {
                case .bitcoin:
                    operation = try BitcoinTransferToAddressOperation(
                        payment: payment,
                        decimalAmount: amount
                    )
                case .evm(let chainID):
                    guard let fee else {
                        throw ReviewError.feeNotReady
                    }
                    let op = try EVMTransferToAddressOperation(
                        evmChainID: chainID,
                        payment: payment,
                        decimalAmount: amount,
                        feePolicy: .prefersGasless,
                    )
                    op.load(fee: fee)
                    operation = op
                case .solana:
                    guard let solanaFeeCalculatingOperation, let fee else {
                        throw ReviewError.feeNotReady
                    }
                    let op = try SolanaTransferToAddressOperation(
                        payment: payment,
                        decimalAmount: amount,
                        feePolicy: .prefersGasless,
                    )
                    op.load(
                        fee: fee,
                        receiverAccountStatus: solanaFeeCalculatingOperation.receiverAccountStatus,
                        nativeTransferContext: solanaFeeCalculatingOperation.nativeTransferContext,
                    )
                    operation = op
                }
                await MainActor.run {
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
            await MainActor.run {
                if let initError {
                    showAutoHiddenHud(style: .error, text: "\(initError)")
                }
                self.reviewButton.isEnabled = true
                self.reviewButton.isBusy = false
            }
        }
    }
    
    override func addFee(_ sender: Any) {
        guard let feeToken = fee?.selected.token else {
            return
        }
        let selector = AddTokenMethodSelectorViewController(token: feeToken)
        selector.delegate = self
        present(selector, animated: true)
    }
    
    override func inputMultipliedAmount(_ sender: UIButton) {
        guard let fee = fee?.selected else {
            return
        }
        let multiplier = self.multiplier(tag: sender.tag)
        if let bitcoinFeeCalculator, multiplier == 1 {
            let maxAmount = bitcoinFeeCalculator.exhaustingOutputsTransferAmount()
            replaceAmount(maxAmount)
        } else if payment.token.assetID == fee.token.assetID {
            let availableBalance = availableBalance(fee: fee)
            replaceAmount(availableBalance * multiplier)
        } else {
            replaceAmount(token.decimalBalance * multiplier)
        }
    }
    
    override func reloadViewsWithBalanceRequirements() {
        guard let fee = fee?.selected, tokenAmount > 0 else {
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
        let receiverAccountStatus = solanaFeeCalculatingOperation?.receiverAccountStatus
        switch receiverAccountStatus {
        case .none, .unknown, .notInvolved:
            if payment.chain == .bitcoin {
                if tokenAmount < Bitcoin.spendingDust {
                    transferAmountFailure = .bitcoinDust
                } else {
                    transferAmountFailure = nil
                }
            } else {
                transferAmountFailure = nil
            }
        case .exist, .notExist:
            let accountExists = receiverAccountStatus == .exist
            let reason = if payment.sendingNativeToken {
                Solana.checkRentExemptionForSOLTransfer(
                    sendingAmount: tokenAmount,
                    feeAmount: fee.amount,
                    senderSOLBalance: payment.token.decimalBalance,
                    receiverAccountExists: accountExists
                )
            } else {
                Solana.checkRentExemptionForSPLTokenTransfer(
                    senderSOLBalance: fee.token.decimalBalance,
                    feeAmount: fee.amount,
                    receiverAccountExists: accountExists
                )
            }
            if let reason {
                transferAmountFailure = .solanaRentExemption(reason)
            } else {
                transferAmountFailure = nil
            }
        }
        
        let feeRequirement = switch fee.token.assetID {
        case AssetID.sol:
            BalanceRequirement(
                token: fee.token,
                amount: fee.amount - Solana.RentExemptionValue.tokenAccount
            )
        default:
            BalanceRequirement(
                token: fee.token,
                amount: fee.amount
            )
        }
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
    
    override func changeFee(_ sender: UIButton) {
        guard let fee else {
            return
        }
        let selector = NetworkFeeSelectorViewController(
            fees: fee.options,
            selectedIndex: fee.selectedIndex
        ) { index in
            self.fee?.selectedIndex = index
            if let fee = self.fee?.selected {
                self.updateFeeDisplay(fee: fee)
            }
            self.reloadViewsWithBalanceRequirements()
        }
        present(selector, animated: true)
    }
    
}

extension Web3TransferInputAmountViewController: AddTokenMethodSelectorViewController.Delegate {
    
    func addTokenMethodSelectorViewController(
        _ viewController: AddTokenMethodSelectorViewController,
        didPickMethod method: AddTokenMethodSelectorViewController.Method
    ) {
        guard let feeToken = fee?.selected.token else {
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
    
    private enum ReviewError: Error {
        case feeNotReady
    }
    
    @MainActor
    private func reloadFee(
        payment: Web3SendingTokenToAddressPayment,
        transferAmount: Decimal,
    ) {
        let bitcoinFeeCalculator = self.bitcoinFeeCalculator
        feeCalculatingTask = Task {
            do {
                let fee: Web3TransferOperation.Fee
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
                    }
                    do {
                        let feeResult = try calculator.calculate(
                            transferAmount: transferAmount == 0 ? 1 * .satoshi : transferAmount
                        )
                        fee = .native(token: feeToken, amount: feeResult.feeAmount)
                    } catch Bitcoin.P2WPKHFeeCalculator.CalculateError.insufficientOutputs(let feeAmount) {
                        fee = .native(token: feeToken, amount: feeAmount)
                    } catch {
                        throw error
                    }
                    await MainActor.run {
                        self.bitcoinFeeCalculator = calculator
                        self.solanaFeeCalculatingOperation = nil
                    }
                case .evm(let chainID):
                    let operation = try EVMTransferToAddressOperation(
                        evmChainID: chainID,
                        payment: payment,
                        decimalAmount: 0,
                        feePolicy: .prefersGasless,
                    )
                    fee = try await operation.reloadFee()
                    await MainActor.run {
                        self.bitcoinFeeCalculator = nil
                        self.solanaFeeCalculatingOperation = nil
                    }
                case .solana:
                    let operation = try SolanaTransferToAddressOperation(
                        payment: payment,
                        decimalAmount: 0,
                        feePolicy: .prefersGasless,
                    )
                    fee = try await operation.reloadFee()
                    await MainActor.run {
                        self.bitcoinFeeCalculator = nil
                        self.solanaFeeCalculatingOperation = operation
                    }
                }
                let isFeeWaived = payment.toAddressLabel?.isFeeWaived() ?? false
                await MainActor.run {
                    self.fee = fee
                    self.feeActivityIndicator?.stopAnimating()
                    self.updateFeeView(style: isFeeWaived ? .waived : .normal)
                    self.updateFeeDisplay(fee: fee.selected)
                    if let button = self.changeFeeButton {
                        button.alpha = 1
                        if fee.options.count > 1 {
                            button.configuration?.image = R.image.arrow_down_compact()
                            button.isUserInteractionEnabled = true
                        } else {
                            button.configuration?.image = nil
                            button.isUserInteractionEnabled = false
                        }
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
    
    private func updateFeeDisplay(fee: Web3DisplayFee) {
        changeFeeButton?.configuration?.title = CurrencyFormatter.localizedString(
            from: fee.amount,
            format: .precision,
            sign: .never,
            symbol: .custom(fee.token.symbol)
        )
        let availableBalance = availableBalance(fee: fee)
        tokenBalanceLabel.text = R.string.localizable.available_balance_count(
            CurrencyFormatter.localizedString(
                from: availableBalance,
                format: .precision,
                sign: .never,
                symbol: .custom(token.symbol)
            )
        )
    }
    
    private func availableBalance(fee: Web3DisplayFee) -> Decimal {
        if payment.token.assetID == fee.token.assetID {
            let amount = switch payment.chain.kind {
            case .solana where payment.sendingNativeToken:
                payment.token.decimalBalance - fee.amount - Solana.RentExemptionValue.systemAccount
            case .bitcoin, .evm, .solana:
                payment.token.decimalBalance - fee.amount
            }
            return max(0, amount)
        } else {
            return payment.token.decimalBalance
        }
    }
    
}
