import UIKit
import MixinServices

final class ReducePerpsPositionMarginViewController: ReduceToPerpsPositionViewController {
    
    override var positionViewModel: PerpetualPositionViewModel {
        didSet {
            liquidationPriceBeforeReducing = positionViewModel.decimalLiquidationPrice?.formatted(
                marketViewModel.userDisplayPriceFormatStyle
            ) ?? "-"
            refreshInput(refreshValidation: true)
        }
    }
    
    override var totalAmount: Decimal {
        positionViewModel.decimalMargin
    }
    
    override var absoluteAmount: Decimal {
        switch input.mode {
        case .byAmount:
            return input.value
        case .byPercentage:
            var amount = totalAmount * input.value
            var result = Decimal()
            NSDecimalRound(&result, &amount, Int(MixinToken.internalPrecision), .down)
            return result
        }
    }
    
    private let liquidationPriceRequester: EditPerpsPositionLiquidationPriceRequester
    
    private var marginDescription: DescriptionRow!
    private var liquidationPriceDescription: DescriptionRow!
    private var liquidationPriceBeforeReducing: String
    private var validatedMargin: Decimal?
    private var maximumRemovableAmount: Decimal?
    
    override init(
        wallet: Wallet,
        marketViewModel: PerpetualMarketViewModel,
        positionViewModel: PerpetualPositionViewModel,
        initialPercentage: Decimal,
    ) {
        self.liquidationPriceRequester = EditPerpsPositionLiquidationPriceRequester(
            positionID: positionViewModel.position.positionID,
            action: .decreaseMargin,
        )
        self.liquidationPriceBeforeReducing = positionViewModel.decimalLiquidationPrice?.formatted(
            marketViewModel.userDisplayPriceFormatStyle
        ) ?? "-"
        super.init(
            wallet: wallet,
            marketViewModel: marketViewModel,
            positionViewModel: positionViewModel,
            initialPercentage: initialPercentage,
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleView.titleLabel.text = R.string.localizable.perps_reduce_margin_title(
            positionViewModel.side.localizedName,
            marketViewModel.market.tokenSymbol
        )
        valueTitleLabel.text = R.string.localizable.perps_margin_amount()
        marginDescription = addDescription(
            title: R.string.localizable.margin(),
            infoAction: #selector(introduceMargin(_:)),
            showsActivityIndicator: false,
        )
        liquidationPriceDescription = addDescription(
            title: R.string.localizable.liquidation_price(),
            infoAction: #selector(introduceLiquidationPrice(_:)),
            showsActivityIndicator: true,
        )
        errorDescriptionButton.addTarget(
            self,
            action: #selector(inputMaximumRemovable(_:)),
            for: .touchUpInside
        )
        updateDescriptions(refreshValidation: false)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil,
        )
        valueTextField.becomeFirstResponder()
        
        var tags: [String: String] = [:]
        tags["source"] = UserOperationAnalytics.tradeSource?.rawValue
        reporter.report(event: .tradePerpsReduceMarginStart, tags: tags)
    }
    
    override func selectReduction(percentage: Decimal, amount: Decimal) {
        switch amountDisplay {
        case .byAmount:
            inputAmount(amount)
        case .byPercentage:
            inputPercentage(percentage)
        }
    }
    
    override func updateDescriptions(refreshValidation: Bool) {
        let reducingAmount = absoluteAmount
        if refreshValidation || reducingAmount <= 0 {
            validatedMargin = nil
            liquidationPriceRequester.cancelLastRequest()
            showError(description: nil)
        }
        let before = CurrencyFormatter.localizedString(
            from: positionViewModel.decimalMargin,
            format: .fiatMoneyPretty,
            sign: .never,
            symbol: .dollarSign
        )
        if reducingAmount > 0, reducingAmount <= positionViewModel.decimalMargin {
            let after = CurrencyFormatter.localizedString(
                from: positionViewModel.decimalMargin - reducingAmount,
                format: .fiatMoneyPretty,
                sign: .never,
                symbol: .dollarSign
            )
            marginDescription.contentLabel.text = PerpPositionAdjustment.change(from: before, to: after)
        } else {
            marginDescription.contentLabel.text = before
        }
        
        guard reducingAmount > 0 else {
            show(liquidationPrice: .invalid)
            return
        }
        if refreshValidation {
            show(liquidationPrice: .busy)
            liquidationPriceRequester.request(
                amount: reducingAmount,
                symbol: nil,
            ) { [weak self] price in
                guard let self else {
                    return
                }
                self.validatedMargin = reducingAmount
                self.showError(description: nil)
                self.show(liquidationPrice: .valid(price: price))
            } onFailure: { [weak self] error in
                guard let self else {
                    return
                }
                self.show(liquidationPrice: .invalid)
                switch error {
                case .exceedsMaxRemovableMargin(let value):
                    self.showMaximumRemovable(value)
                case .other(let description):
                    self.showError(description: description)
                }
            }
        }
    }
    
    override func cancel(_ sender: Any) {
        liquidationPriceRequester.cancelLastRequest()
        super.cancel(sender)
        reporter.report(event: .tradePerpsReduceMarginCancel)
    }
    
    override func reduce(_ sender: Any) {
        guard absoluteAmount > 0, validatedMargin == absoluteAmount else {
            return
        }
        reporter.report(event: .tradePerpsReduceMarginPreview)
        valueTextField.resignFirstResponder()
        let preview = ReducePerpsPositionMarginPreviewViewController(
            wallet: wallet,
            marketViewModel: marketViewModel,
            positionViewModel: positionViewModel,
            reducingMargin: absoluteAmount,
            onDismissAfterSuccess: { [weak self] in
                self?.presentingViewController?.dismiss(animated: true)
            }
        )
        present(preview, animated: true)
    }
    
    @objc private func applicationDidBecomeActive() {
        guard viewIfLoaded?.window != nil, presentedViewController == nil else {
            return
        }
        valueTextField.becomeFirstResponder()
    }
    
    @objc private func introduceMargin(_ sender: Any) {
        present(PopupAlertViewController.perpsMargin(), animated: true)
    }
    
    @objc private func introduceLiquidationPrice(_ sender: Any) {
        let manual = PerpsManual.viewController(initialPage: .liquidation)
        present(manual, animated: true)
        reporter.report(
            event: .tradePerpsGuide,
            tags: ["source": "perps_reduce_margin_liquidation"]
        )
    }
    
    @objc private func inputMaximumRemovable(_ sender: UIButton) {
        guard let maximumRemovableAmount else {
            return
        }
        inputAmount(maximumRemovableAmount)
    }
    
}

extension ReducePerpsPositionMarginViewController {
    
    private enum LiquidationPrice {
        case invalid
        case busy
        case valid(price: Decimal)
    }
    
    private func show(liquidationPrice: LiquidationPrice) {
        switch liquidationPrice {
        case .invalid:
            liquidationPriceDescription.activityIndicator?.stopAnimating()
            validatedMargin = nil
            liquidationPriceDescription.contentLabel.text = liquidationPriceBeforeReducing
            liquidationPriceDescription.contentLabel.alpha = 1
            confirmButton.isEnabled = false
        case .busy:
            liquidationPriceDescription.activityIndicator?.startAnimating()
            liquidationPriceDescription.contentLabel.alpha = 0
            confirmButton.isEnabled = false
        case let .valid(price):
            liquidationPriceDescription.activityIndicator?.stopAnimating()
            let after = price.formatted(
                marketViewModel.userDisplayPriceFormatStyle
            )
            liquidationPriceDescription.contentLabel.text = PerpPositionAdjustment.change(
                from: liquidationPriceBeforeReducing,
                to: after,
            )
            liquidationPriceDescription.contentLabel.alpha = 1
            confirmButton.isEnabled = true
        }
    }
    
    private func showMaximumRemovable(_ amount: Decimal) {
        let value: String
        let removableAmount: Decimal
        switch amountDisplay {
        case .byAmount:
            var reducingAmount: Decimal = 0
            if amount < 0.01 {
                reducingAmount = amount
            } else {
                withUnsafePointer(to: amount) { amount in
                    NSDecimalRound(&reducingAmount, amount, 2, .down)
                }
            }
            value = CurrencyFormatter.localizedString(
                from: reducingAmount,
                format: .precision,
                sign: .never,
                symbol: .dollarSign
            )
            removableAmount = reducingAmount
        case .byPercentage:
            let hasInputFractionals: Bool
            if var inputPercentage = Decimal(string: valueTextField.text ?? "", locale: .current) {
                var integralPart: Decimal = 0
                NSDecimalRound(&integralPart, &inputPercentage, 0, .down)
                hasInputFractionals = inputPercentage != integralPart
            } else {
                hasInputFractionals = false
            }
            
            let margin = positionViewModel.decimalMargin
            let recommendedPercentage = {
                let percentage = margin > 0 ? amount / margin : 0
                let scale = hasInputFractionals || percentage < 0.01 ? 4 : 2
                var roundedPercentage: Decimal = 0
                withUnsafePointer(to: percentage) { percentage in
                    NSDecimalRound(&roundedPercentage, percentage, scale, .down)
                }
                return roundedPercentage
            }()
            
            value = PercentageFormatter.string(
                from: recommendedPercentage,
                format: .pretty,
                sign: .never
            )
            removableAmount = {
                let amount = margin * recommendedPercentage
                var roundedAmount: Decimal = 0
                withUnsafePointer(to: amount) { amount in
                    NSDecimalRound(&roundedAmount, amount, Int(MixinToken.internalPrecision), .down)
                }
                return roundedAmount
            }()
        }
        showError(description: R.string.localizable.max_removable(value))
        maximumRemovableAmount = removableAmount
        errorDescriptionButton.isEnabled = true
    }
    
    private func showError(description: String?) {
        maximumRemovableAmount = nil
        showError(description: description, color: R.color.market_red()!)
    }
    
}
