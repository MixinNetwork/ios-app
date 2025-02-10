import UIKit
import MixinServices

final class WithdrawInputAmountViewController: InputAmountViewController {
    
    override var token: any TransferableToken {
        tokenItem
    }
    
    override var isBalanceInsufficient: Bool {
        if let fee = selectedFeeItem {
            if feeTokenSameAsWithdrawToken {
                tokenAmount > tokenItem.decimalBalance - fee.amount
            } else {
                super.isBalanceInsufficient
            }
        } else {
            false
        }
    }
    
    private let tokenItem: TokenItem
    private let destination: Payment.WithdrawalDestination
    private let progress: UserInteractionProgress
    private let traceID = UUID().uuidString.lowercased()
    
    private var feeTokenSameAsWithdrawToken = false
    private var selectableFeeItems: [WithdrawFeeItem]?
    private var selectedFeeItemIndex: Int?
    private var selectedFeeItem: WithdrawFeeItem? {
        if let selectableFeeItems, let selectedFeeItemIndex {
            return selectableFeeItems[selectedFeeItemIndex]
        } else {
            return nil
        }
    }
    
    init(
        tokenItem: TokenItem,
        destination: Payment.WithdrawalDestination,
        progress: UserInteractionProgress
    ) {
        self.tokenItem = tokenItem
        self.destination = destination
        self.progress = progress
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = NavigationTitleView(
            title: R.string.localizable.send(),
            subtitle: progress.description
        )
        
        tokenIconView.setIcon(token: tokenItem)
        tokenNameLabel.text = tokenItem.name
        tokenBalanceLabel.text = tokenItem.localizedBalanceWithSymbol
        
        addFeeView()
        changeFeeButton?.addTarget(self, action: #selector(changeFee(_:)), for: .touchUpInside)
        reloadWithdrawFee(with: tokenItem, destination: destination)
    }
    
    override func review(_ sender: Any) {
        guard let feeItem = selectedFeeItem, !reviewButton.isBusy else {
            return
        }
        reviewButton.isBusy = true
        
        let payment = Payment(
            traceID: traceID,
            token: tokenItem,
            tokenAmount: tokenAmount,
            fiatMoneyAmount: fiatMoneyAmount,
            memo: ""
        )
        payment.checkPreconditions(
            withdrawTo: destination,
            fee: feeItem,
            on: self
        ) { reason in
            self.reviewButton.isBusy = false
            switch reason {
            case .userCancelled, .loggedOut:
                break
            case .description(let message):
                showAutoHiddenHud(style: .error, text: message)
            }
        } onSuccess: { [amountIntent, destination] (operation, issues) in
            self.reviewButton.isBusy = false
            let addressLabel: String? = switch destination {
            case .address(let address):
                address.label
            case .temporary, .web3:
                nil
            }
            let preview = WithdrawPreviewViewController(
                issues: issues,
                operation: operation,
                amountDisplay: amountIntent,
                withdrawalTokenAmount: payment.tokenAmount,
                withdrawalFiatMoneyAmount: payment.fiatMoneyAmount,
                addressLabel: addressLabel
            )
            self.present(preview, animated: true)
        }
    }
    
    override func inputMultipliedAmount(_ sender: UIButton) {
        guard let fee = selectedFeeItem else {
            return
        }
        let multiplier = self.multiplier(tag: sender.tag)
        if feeTokenSameAsWithdrawToken {
            let availableBalance = max(0, tokenItem.decimalBalance - fee.amount)
            replaceAmount(availableBalance * multiplier)
        } else {
            replaceAmount(token.decimalBalance * multiplier)
        }
    }
    
    @objc private func changeFee(_ sender: UIButton) {
        guard let selectableFeeItems, let selectedFeeItemIndex else {
            return
        }
        let selector = WithdrawFeeSelectorViewController(
            fees: selectableFeeItems,
            selectedIndex: selectedFeeItemIndex
        ) { index in
            let feeToken = selectableFeeItems[index]
            self.feeTokenSameAsWithdrawToken = feeToken.tokenItem.assetID == self.tokenItem.assetID
            self.selectedFeeItemIndex = index
            self.updateFeeDisplay(feeToken: feeToken)
        }
        present(selector, animated: true)
    }
    
    private func updateFeeDisplay(feeToken: WithdrawFeeItem) {
        let title = if feeToken.amount == 0 {
            "0"
        } else {
            CurrencyFormatter.localizedString(
                from: feeToken.amount,
                format: .precision,
                sign: .never,
                symbol: .custom(feeToken.tokenItem.symbol)
            )
        }
        changeFeeButton?.configuration?.attributedTitle = AttributedString(title, attributes: feeAttributes)
        let availableBalance = if feeTokenSameAsWithdrawToken {
            CurrencyFormatter.localizedString(
                from: max(0, tokenItem.decimalBalance - feeToken.amount),
                format: .precision,
                sign: .never,
                symbol: .custom(feeToken.tokenItem.symbol)
            )
        } else {
            tokenItem.localizedBalanceWithSymbol
        }
        tokenBalanceLabel.text = R.string.localizable.available_balance(availableBalance)
    }
    
    private func reloadWithdrawFee(with token: TokenItem, destination: Payment.WithdrawalDestination) {
        reviewButton.isBusy = true
        Task {
            do {
                let fees = try await SafeAPI.fees(assetID: token.assetID, destination: destination.destination)
                guard let fee = fees.first else {
                    throw MixinAPIResponseError.withdrawSuspended
                }
                let allAssetIDs = fees.map(\.assetID)
                let tokensMap = TokenDAO.shared.tokenItems(with: allAssetIDs)
                    .reduce(into: [:]) { result, item in
                        result[item.assetID] = item
                    }
                let feeTokens: [WithdrawFeeItem] = fees.compactMap { fee in
                    if let token = tokensMap[fee.assetID] {
                        return WithdrawFeeItem(amountString: fee.amount, tokenItem: token)
                    } else {
                        return nil
                    }
                }
                guard let feeToken = feeTokens.first, feeToken.tokenItem.assetID == fee.assetID else {
                    return
                }
                let feeTokenSameAsWithdrawToken = fee.assetID == token.assetID
                await MainActor.run {
                    self.feeTokenSameAsWithdrawToken = feeTokenSameAsWithdrawToken
                    self.selectedFeeItemIndex = 0
                    self.selectableFeeItems = feeTokens
                    self.feeActivityIndicator?.stopAnimating()
                    self.updateFeeDisplay(feeToken: feeToken)
                    if let button = self.changeFeeButton {
                        button.alpha = 1
                        if feeTokens.count > 1 {
                            button.configuration?.image = R.image.arrow_down_compact()
                            button.isUserInteractionEnabled = true
                        } else {
                            button.configuration?.image = nil
                            button.isUserInteractionEnabled = false
                        }
                    }
                    self.reviewButton.isBusy = false
                }
            } catch MixinAPIResponseError.withdrawSuspended {
                await MainActor.run {
                    let suspended = WalletHintViewController(content: .withdrawSuspended(token))
                    suspended.delegate = self
                    present(suspended, animated: true)
                }
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    // Check token and address
                    self?.reloadWithdrawFee(with: token, destination: destination)
                }
            }
        }
    }
    
}

extension WithdrawInputAmountViewController: WalletHintViewControllerDelegate {
    
    func walletHintViewControllerDidRealize(_ controller: WalletHintViewController) {
        navigationController?.popViewController(animated: true)
    }
    
    func walletHintViewControllerWantsContactSupport(_ controller: WalletHintViewController) {
        guard let navigationController, let user = UserDAO.shared.getUser(identityNumber: "7000") else {
            return
        }
        let conversation = ConversationViewController.instance(ownerUser: user)
        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.firstIndex(where: { $0 is HomeTabBarController }) {
            viewControllers.removeLast(viewControllers.count - index - 1)
        }
        viewControllers.append(conversation)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
}
