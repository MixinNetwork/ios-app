import UIKit
import MixinServices

final class WithdrawInputAmountViewController: FeeRequiredInputAmountViewController {
    
    private let tokenItem: MixinTokenItem
    private let destination: Payment.WithdrawalDestination
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
        tokenItem: MixinTokenItem,
        destination: Payment.WithdrawalDestination
    ) {
        self.tokenItem = tokenItem
        self.destination = destination
        super.init(token: tokenItem, precision: MixinToken.precision)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleView = NavigationTitleView(title: R.string.localizable.send_to_title())
        switch destination {
        case .address(let address):
            titleView.subtitle = address.label
            titleView.subtitleStyle = .label(backgroundColor: R.color.address_label()!)
        case .temporary(let address):
            titleView.subtitle = address.compactRepresentation
            titleView.subtitleStyle = .plain
        case .commonWallet:
            titleView.subtitle = R.string.localizable.common_wallet()
            titleView.subtitleStyle = .label(backgroundColor: R.color.wallet_label()!)
        }
        navigationItem.titleView = titleView
        
        tokenIconView.setIcon(token: tokenItem)
        tokenNameLabel.text = tokenItem.name
        tokenBalanceLabel.text = tokenItem.localizedBalanceWithSymbol
        
        addFeeView()
        changeFeeButton?.addTarget(self, action: #selector(changeFee(_:)), for: .touchUpInside)
        reloadWithdrawFee(with: tokenItem, destination: destination)
        
        reporter.report(event: .sendAmount)
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
        } onSuccess: { [amountIntent] (operation, issues) in
            self.reviewButton.isBusy = false
            let preview = WithdrawPreviewViewController(
                issues: issues,
                operation: operation,
                amountDisplay: amountIntent,
            )
            self.present(preview, animated: true)
        }
    }
    
    override func addFee(_ sender: Any) {
        guard let feeToken = selectedFeeItem?.tokenItem else {
            return
        }
        let selector = AddTokenMethodSelectorViewController(token: feeToken)
        selector.delegate = self
        present(selector, animated: true)
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
    
    override func reloadViewsWithBalanceRequirements() {
        guard let fee = selectedFeeItem else {
            insufficientBalanceLabel.text = nil
            reviewButton.isEnabled = false
            return
        }
        let feeRequirement = BalanceRequirement(token: fee.tokenItem, amount: fee.amount)
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
                insufficientBalanceLabel.text = R.string.localizable.withdraw_insufficient_fee_count(
                    feeRequirement.localizedAmountWithSymbol,
                    feeRequirement.token.localizedBalanceWithSymbol
                )
                addAddFeeButton(symbol: feeRequirement.token.symbol)
            }
            reviewButton.isEnabled = false
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
            let feeItem = selectableFeeItems[index]
            self.feeTokenSameAsWithdrawToken = feeItem.tokenItem.assetID == self.tokenItem.assetID
            self.selectedFeeItemIndex = index
            self.reloadViewsWithBalanceRequirements()
            self.updateFeeDisplay(fee: feeItem)
        }
        present(selector, animated: true)
    }
    
    private func updateFeeDisplay(fee: WithdrawFeeItem) {
        changeFeeButton?.configuration?.attributedTitle = AttributedString(
            fee.localizedAmountWithSymbol,
            attributes: feeAttributes
        )
        let availableBalance = if feeTokenSameAsWithdrawToken {
            CurrencyFormatter.localizedString(
                from: max(0, tokenItem.decimalBalance - fee.amount),
                format: .precision,
                sign: .never,
                symbol: .custom(fee.tokenItem.symbol)
            )
        } else {
            tokenItem.localizedBalanceWithSymbol
        }
        tokenBalanceLabel.text = R.string.localizable.available_balance_count(availableBalance)
    }
    
    private func reloadWithdrawFee(with token: MixinTokenItem, destination: Payment.WithdrawalDestination) {
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
                let feeItems: [WithdrawFeeItem] = fees.compactMap { fee in
                    if let token = tokensMap[fee.assetID] {
                        return WithdrawFeeItem(amountString: fee.amount, tokenItem: token)
                    } else {
                        return nil
                    }
                }
                guard let feeToken = feeItems.first, feeToken.tokenItem.assetID == fee.assetID else {
                    return
                }
                let feeTokenSameAsWithdrawToken = fee.assetID == token.assetID
                await MainActor.run {
                    self.feeTokenSameAsWithdrawToken = feeTokenSameAsWithdrawToken
                    self.selectedFeeItemIndex = 0
                    self.selectableFeeItems = feeItems
                    self.feeActivityIndicator?.stopAnimating()
                    self.reloadViewsWithBalanceRequirements()
                    self.updateFeeDisplay(fee: feeToken)
                    if let button = self.changeFeeButton {
                        button.alpha = 1
                        if feeItems.count > 1 {
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

extension WithdrawInputAmountViewController: AddTokenMethodSelectorViewController.Delegate {
    
    func addTokenMethodSelectorViewController(
        _ viewController: AddTokenMethodSelectorViewController,
        didPickMethod method: AddTokenMethodSelectorViewController.Method
    ) {
        guard let feeToken = selectedFeeItem?.tokenItem else {
            return
        }
        let next = switch method {
        case .swap:
            MixinSwapViewController(
                sendAssetID: nil,
                receiveAssetID: feeToken.assetID,
                referral: nil
            )
        case .deposit:
            DepositViewController(token: feeToken)
        }
        navigationController?.pushViewController(next, animated: true)
    }
    
}
