import UIKit
import MixinServices

final class WithdrawInputAmountViewController: InputAmountViewController {
    
    override var token: any TransferableToken {
        tokenItem
    }
    
    override var isBalanceInsufficient: Bool {
        if let fee = selectedFeeItem, feeTokenSameAsWithdrawToken {
            tokenAmount > tokenItem.decimalBalance - fee.amount
        } else {
            super.isBalanceInsufficient
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
    
    private weak var activityIndicator: ActivityIndicatorView!
    private weak var changeFeeButton: UIButton!
    
    private var feeAttributes: AttributeContainer {
        var container = AttributeContainer()
        container.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        container.foregroundColor = R.color.text_tertiary()
        return container
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
        
        let feeStackView = {
            let titleLabel = InsetLabel()
            titleLabel.contentInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
            titleLabel.text = R.string.localizable.network_fee()
            titleLabel.textColor = R.color.text_tertiary()
            titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            let activityIndicator = ActivityIndicatorView()
            activityIndicator.style = .custom(diameter: 16, lineWidth: 2)
            activityIndicator.tintColor = R.color.chat_pin_count_background()
            activityIndicator.hidesWhenStopped = true
            activityIndicator.isAnimating = true
            self.activityIndicator = activityIndicator
            
            var config: UIButton.Configuration = .plain()
            config.baseBackgroundColor = .clear
            config.imagePlacement = .trailing
            config.imagePadding = 14
            config.attributedTitle = AttributedString("0", attributes: feeAttributes)
            let button = UIButton(configuration: config)
            button.tintColor = R.color.chat_pin_count_background()
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            button.addTarget(self, action: #selector(changeFee(_:)), for: .touchUpInside)
            button.alpha = 0
            self.changeFeeButton = button
            
            let stackView = UIStackView(arrangedSubviews: [titleLabel, activityIndicator, button])
            stackView.axis = .horizontal
            stackView.alignment = .center
            return stackView
        }()
        accessoryStackView.insertArrangedSubview(feeStackView, at: 0)
        feeStackView.snp.makeConstraints { make in
            make.width.equalTo(view.snp.width).offset(-56)
        }
        
        tokenIconView.setIcon(token: tokenItem)
        tokenNameLabel.text = tokenItem.name
        tokenBalanceLabel.text = tokenItem.localizedBalanceWithSymbol
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
        let multiplier = self.multiplier(tag: sender.tag)
        if let fee = selectedFeeItem, feeTokenSameAsWithdrawToken {
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
        changeFeeButton.configuration?.attributedTitle = AttributedString(title, attributes: feeAttributes)
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
                    self.activityIndicator.stopAnimating()
                    self.updateFeeDisplay(feeToken: feeToken)
                    self.changeFeeButton.alpha = 1
                    if feeTokens.count > 1 {
                        self.changeFeeButton.configuration?.image = R.image.arrow_down_compact()
                        self.changeFeeButton.isUserInteractionEnabled = true
                    } else {
                        self.changeFeeButton.configuration?.image = R.image.arrow_down_compact()
                        self.changeFeeButton.isUserInteractionEnabled = false
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
