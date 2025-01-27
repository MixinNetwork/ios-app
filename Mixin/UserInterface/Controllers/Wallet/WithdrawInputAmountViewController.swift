import UIKit
import MixinServices

final class WithdrawInputAmountViewController: InputAmountViewController {
    
    override var token: any Web3TransferableToken {
        tokenItem
    }
    
    private let tokenItem: TokenItem
    private let address: Address
    private let traceID = UUID().uuidString.lowercased()
    
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
    
    init(tokenItem: TokenItem, address: Address) {
        self.tokenItem = tokenItem
        self.address = address
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.send()
        
        let noteStackView = {
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
            let button = UIButton(configuration: config)
            button.tintColor = R.color.chat_pin_count_background()
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            button.addTarget(self, action: #selector(changeFee(_:)), for: .touchUpInside)
            button.isHidden = true
            self.changeFeeButton = button
            
            let stackView = UIStackView(arrangedSubviews: [titleLabel, activityIndicator, button])
            stackView.axis = .horizontal
            stackView.alignment = .center
            return stackView
        }()
        accessoryStackView.insertArrangedSubview(noteStackView, at: 0)
        
        tokenIconView.setIcon(token: tokenItem)
        tokenNameLabel.text = tokenItem.name
        tokenBalanceLabel.text = tokenItem.localizedBalanceWithSymbol
        inputMaxValueButton.isHidden = true
        
        addMultipliersView()
        
        reloadWithdrawFee(with: tokenItem, address: address)
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
        let onPreconditonFailure = { (reason: PaymentPreconditionFailureReason) in
            self.reviewButton.isBusy = false
            switch reason {
            case .userCancelled, .loggedOut:
                break
            case .description(let message):
                showAutoHiddenHud(style: .error, text: message)
            }
        }
        payment.checkPreconditions(
            withdrawTo: .address(address),
            fee: feeItem,
            on: self,
            onFailure: onPreconditonFailure
        ) { [amountIntent, address] (operation, issues) in
            self.reviewButton.isBusy = false
            let preview = WithdrawPreviewViewController(
                issues: issues,
                operation: operation,
                amountDisplay: amountIntent,
                withdrawalTokenAmount: payment.tokenAmount,
                withdrawalFiatMoneyAmount: payment.fiatMoneyAmount,
                addressLabel: address.label
            )
            self.present(preview, animated: true)
        }
    }
    
    @objc private func changeFee(_ sender: UIButton) {
        guard let selectableFeeItems, let selectedFeeItemIndex else {
            return
        }
        let selector = WithdrawFeeSelectorViewController(fees: selectableFeeItems, selectedIndex: selectedFeeItemIndex) { index in
            self.selectedFeeItemIndex = index
            let feeToken = selectableFeeItems[index]
            self.updateNetworkFeeLabel(feeToken: feeToken)
        }
        present(selector, animated: true)
    }
    
    private func updateNetworkFeeLabel(feeToken: WithdrawFeeItem) {
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
    }
    
    private func reloadWithdrawFee(with token: TokenItem, address: Address) {
        reviewButton.isBusy = true
        Task {
            do {
                let fees = try await SafeAPI.fees(assetID: token.assetID, destination: address.destination)
                guard let fee = fees.first else {
                    throw MixinAPIResponseError.withdrawSuspended
                }
                let allAssetIDs = fees.map(\.assetID)
                let missingAssetIDs = TokenDAO.shared.inexistAssetIDs(in: allAssetIDs)
                if !missingAssetIDs.isEmpty {
                    let tokens = try await SafeAPI.assets(ids: missingAssetIDs)
                    await withCheckedContinuation { continuation in
                        TokenDAO.shared.save(assets: tokens) {
                            continuation.resume()
                        }
                    }
                }
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
                guard feeTokens.first?.tokenItem.assetID == fee.assetID else {
                    return
                }
                let feeToken = feeTokens[0]
                await MainActor.run {
                    self.selectedFeeItemIndex = 0
                    self.selectableFeeItems = feeTokens
                    self.activityIndicator.stopAnimating()
                    self.updateNetworkFeeLabel(feeToken: feeToken)
                    self.changeFeeButton.isHidden = false
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
                    self?.reloadWithdrawFee(with: token, address: address)
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
