import UIKit
import MixinServices

final class ClosePerpsPositionViewController: ReduceToPerpsPositionViewController {
    
    override var marketViewModel: PerpetualMarketViewModel {
        didSet {
            hasValidQuantityScale = true
            refreshInput(refreshValidation: false)
        }
    }
    
    override var positionViewModel: PerpetualPositionViewModel {
        didSet {
            refreshInput(refreshValidation: true)
        }
    }
    
    override var totalAmount: Decimal {
        positionViewModel.decimalQuantity * positionViewModel.position.decimalMarkPrice
    }
    
    private var receivingDescription: DescriptionRow!
    private var marginDescription: DescriptionRow!
    private var sizeDescription: DescriptionRow!
    private var feeDescription: DescriptionRow!
    private var hasValidQuantityScale: Bool
    private var validatedQuantity: Decimal?
    
    override init(
        wallet: Wallet,
        marketViewModel: PerpetualMarketViewModel,
        positionViewModel: PerpetualPositionViewModel,
        initialPercentage: Decimal,
    ) {
        self.hasValidQuantityScale = marketViewModel.market.quantityScale != 0
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
        
        titleView.titleLabel.text = R.string.localizable.perps_close_position_title(
            positionViewModel.side.localizedName,
            marketViewModel.market.tokenSymbol
        )
        receivingDescription = addDescription(
            title: R.string.localizable.estimated_receive(),
            alignment: .center,
            infoAction: nil,
            showsActivityIndicator: false,
        )
        marginDescription = addDescription(
            title: R.string.localizable.margin(),
            alignment: .top,
            infoAction: nil,
            showsActivityIndicator: false,
        )
        sizeDescription = addDescription(
            title: R.string.localizable.position_size(),
            alignment: .center,
            infoAction: #selector(introducePositionSize(_:)),
            showsActivityIndicator: false,
        )
        feeDescription = addDescription(
            title: R.string.localizable.fee(),
            alignment: .center,
            infoAction: #selector(introduceTradingFee(_:)),
            showsActivityIndicator: false,
        )
        updateDescriptions(refreshValidation: false)
        
        var tags: [String: String] = [:]
        tags["source"] = UserOperationAnalytics.tradeSource?.rawValue
        reporter.report(event: .tradePerpsReducePositionStart, tags: tags)
    }
    
    override func inputAmount(_ amount: Decimal) {
        if amount == totalAmount, totalAmount > 0 {
            inputPercentage(1)
        } else {
            super.inputAmount(amount)
        }
    }
    
    override func updateDescriptions(refreshValidation: Bool) {
        let markPrice = positionViewModel.position.decimalMarkPrice
        var validationError: String?
        validatedQuantity = {
            let current = positionViewModel.decimalQuantity
            let quantityScale = marketViewModel.market.quantityScale
            guard quantityScale >= 0, current > 0, input.value > 0 else {
                return nil
            }
            var quantity: Decimal
            switch input.mode {
            case .byPercentage:
                var value = input.value * 100
                var integralValue = Decimal()
                NSDecimalRound(&integralValue, &value, 0, .down)
                guard value == integralValue, value <= 100 else {
                    return nil
                }
                quantity = current * value / 100
            case .byAmount:
                guard markPrice > 0, input.value <= current * markPrice else {
                    return nil
                }
                quantity = input.value / markPrice
            }
            var roundedQuantity = Decimal()
            NSDecimalRound(&roundedQuantity, &quantity, quantityScale, .down)
            guard roundedQuantity > 0, roundedQuantity <= current else {
                return nil
            }
            let minOrderValue = marketViewModel.market.decimalMinOrderValue
            if roundedQuantity == current {
                return roundedQuantity
            } else if roundedQuantity * markPrice < minOrderValue {
                let minimum = CurrencyFormatter.localizedString(
                    from: minOrderValue,
                    format: .precision,
                    sign: .never,
                    symbol: .dollarSign,
                )
                validationError = R.string.localizable.perps_minimum_order_size(minimum)
                return nil
            } else {
                return roundedQuantity
            }
        }()
        if let reducingQuantity = validatedQuantity {
            let remainingQuantity = positionViewModel.decimalQuantity - reducingQuantity
            let sizeBefore = CurrencyFormatter.localizedString(
                from: positionViewModel.decimalQuantity,
                format: .precision,
                sign: .never,
                symbol: .custom(marketViewModel.market.tokenSymbol),
            )
            let sizeAfter = CurrencyFormatter.localizedString(
                from: remainingQuantity,
                format: .precision,
                sign: .never,
                symbol: .custom(marketViewModel.market.tokenSymbol),
            ) + "(" + CurrencyFormatter.localizedString(
                from: remainingQuantity * markPrice,
                format: .fiatMoneyPretty,
                sign: .never,
                symbol: .dollarSign,
            ) + ")"
            sizeDescription.contentLabel.text = PerpPositionAdjustment.change(
                from: sizeBefore,
                to: sizeAfter,
            )
            let proportion = reducingQuantity / positionViewModel.decimalQuantity
            let pnl = positionViewModel.position.decimalUnrealizedPnL * proportion
            let marginPlusPnL = positionViewModel.decimalMargin * proportion + pnl
            marginDescription.contentLabel.attributedText = {
                let description = NSMutableAttributedString(
                    string: CurrencyFormatter.localizedString(
                        from: marginPlusPnL,
                        format: .fiatMoneyPretty,
                        sign: .never,
                        symbol: .dollarSign,
                    ) + "\n",
                    attributes: [.foregroundColor: R.color.text_secondary()!],
                )
                description.append(NSAttributedString(
                    string: R.string.localizable.perps_include_pnl() + " ",
                    attributes: [.foregroundColor: R.color.text_tertiary()!],
                ))
                description.append(NSAttributedString(
                    string: CurrencyFormatter.localizedString(
                        from: pnl,
                        format: .fiatMoneyPretty,
                        sign: .always,
                        symbol: .dollarSign,
                    ),
                    attributes: [.foregroundColor: positionViewModel.pnlColor.uiColor],
                ))
                return description
            }()
            if let estimatedCloseFee = positionViewModel.position.decimalEstimatedCloseFee {
                let fee = estimatedCloseFee * proportion
                receivingDescription.contentLabel.text = CurrencyFormatter.localizedString(
                    from: marginPlusPnL - fee,
                    format: .fiatMoneyPretty,
                    sign: .whenNegative,
                    symbol: .dollarSign,
                )
                feeDescription.contentLabel.text = CurrencyFormatter.localizedString(
                    from: fee,
                    format: .fiatMoneyPretty,
                    sign: .whenNegative,
                    symbol: .dollarSign,
                )
                feeDescription.isHidden = false
            } else {
                receivingDescription.contentLabel.text = "-"
                feeDescription.contentLabel.text = "-"
                feeDescription.isHidden = true
            }
            confirmButton.isEnabled = hasValidQuantityScale
            showError(description: nil)
        } else {
            receivingDescription.contentLabel.text = "-"
            marginDescription.contentLabel.text = "-"
            sizeDescription.contentLabel.text = "-"
            feeDescription.contentLabel.text = "-"
            confirmButton.isEnabled = false
            if input.value != 0 {
                showError(description: validationError ?? R.string.localizable.perps_reduce_invalid_quantity())
            } else {
                showError(description: nil)
            }
        }
    }
    
    override func cancel(_ sender: Any) {
        super.cancel(sender)
        reporter.report(event: .tradePerpsReducePositionCancel)
    }
    
    override func reduce(_ sender: Any) {
        guard hasValidQuantityScale, let reducingQuantity = validatedQuantity else {
            return
        }
        let preview = ClosePerpetualPositionPreviewViewController(
            reducing: positionViewModel,
            quantity: reducingQuantity,
            canonicalFormatStyle: marketViewModel.market.canonicalQuantityFormatStyle,
            onDismissAfterSuccess: { [weak self] in
                self?.presentingViewController?.dismiss(animated: true)
            },
        )
        reporter.report(event: .tradePerpsReducePositionPreview)
        valueTextField.resignFirstResponder()
        present(preview, animated: true)
    }
    
    @objc private func introducePositionSize(_ sender: Any) {
        let manual = PerpsManual.viewController(initialPage: .size)
        present(manual, animated: true)
        reporter.report(
            event: .tradePerpsGuide,
            tags: ["source": "perps_close_position_size"]
        )
    }
    
    @objc private func introduceTradingFee(_ sender: Any) {
        let manual = PerpsManual.viewController(initialPage: .tradingFee)
        present(manual, animated: true)
        reporter.report(
            event: .tradePerpsGuide,
            tags: ["source": "perps_close_position_fee"]
        )
    }
    
    private func showError(description: String?) {
        let color = description == nil ? R.color.text()! : R.color.market_red()!
        updateInputColor(color)
        showError(description: description, color: color)
    }
    
}
