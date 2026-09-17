import UIKit
import MixinServices

final class ReduceToPerpsPositionViewController: UIViewController {
    
    @IBOutlet weak var titleView: EditPerpsPositionTitleView!
    
    @IBOutlet weak var inputBackgroundView: UIView!
    @IBOutlet weak var decreaseMultiplierButton: UIButton!
    @IBOutlet weak var increaseMultiplierButton: UIButton!
    @IBOutlet weak var valueTextField: UITextField!
    @IBOutlet weak var alternativeValueLabel: UILabel!
    @IBOutlet weak var swapValueDisplayImageView: UIImageView!
    @IBOutlet weak var swapValueDisplayButton: UIButton!
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var markingStackView: UIStackView!
    
    @IBOutlet weak var targetTitleLabel: UILabel!
    @IBOutlet weak var targetContentLabel: UILabel!
    @IBOutlet weak var liquidationPriceTitleLabel: UILabel!
    @IBOutlet weak var liquidationPriceContentLabel: UILabel!
    @IBOutlet weak var liquidationPriceActivityIndicator: ActivityIndicatorView!
    
    @IBOutlet weak var actionWrapperView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var reduceButton: UIButton!
    
    private let wallet: Wallet
    private let target: PerpPositionAdjustmentTarget
    private let marketViewModel: PerpetualMarketViewModel
    private let positionViewModel: PerpetualPositionViewModel
    private let liquidationPriceBeforeReducing: String
    private let liquidationPriceRequester: EditPerpsPositionLiquidationPriceRequester
    private let leftSignLabel = UILabel()
    private let rightSignLabel = UILabel()
    private let markingPercentages: [Decimal]
    private let markingAmounts: [Decimal]
    
    private let absoluteAmountUserInputSimulationFormatter = Decimal.FormatStyle.number
        .locale(.current)
        .grouping(.never)
        .sign(strategy: .never)
        .precision(.fractionLength(0...2))
        .rounded(rule: .towardZero)
    private let percentageUserInputSimulationFormatter = Decimal.FormatStyle.number
        .locale(.current)
        .grouping(.never)
        .sign(strategy: .never)
        .precision(.fractionLength(0))
        .rounded(rule: .toNearestOrAwayFromZero)
    
    private var markingButtons: [UIButton] = []
    private var input = Input(mode: .byPercentage, value: 0)
    private var amountDisplay: AmountDisplay = .byPercentage
    private var validatedAmount: Decimal?
    
    private var absoluteAmount: Decimal {
        switch input.mode {
        case .byAmount:
            return input.value
        case .byPercentage:
            var amount = positionViewModel.decimalMargin * input.value
            var result = Decimal()
            NSDecimalRound(&result, &amount, Int(MixinToken.internalPrecision), .down)
            return result
        }
    }
    
    private var percentage: Decimal {
        switch input.mode {
        case .byPercentage:
            return input.value
        case .byAmount:
            let margin = positionViewModel.decimalMargin
            return margin > 0 ? input.value / margin : 0
        }
    }
    
    init(
        wallet: Wallet,
        reducing target: PerpPositionAdjustmentTarget,
        marketViewModel: PerpetualMarketViewModel,
        positionViewModel: PerpetualPositionViewModel,
    ) {
        let markingPercentages: [Decimal] = [0, 0.25, 0.5, 0.75, 1]
        
        self.wallet = wallet
        self.target = target
        self.marketViewModel = marketViewModel
        self.positionViewModel = positionViewModel
        self.liquidationPriceBeforeReducing = positionViewModel.decimalLiquidationPrice?.formatted(
            marketViewModel.userDisplayPriceFormatStyle
        ) ?? "-"
        switch target {
        case .margin:
            self.liquidationPriceRequester = EditPerpsPositionLiquidationPriceRequester(
                positionID: positionViewModel.positionID,
                action: .decreaseMargin,
            )
        case .position:
            assertionFailure("Not ready")
            self.liquidationPriceRequester = EditPerpsPositionLiquidationPriceRequester(
                positionID: positionViewModel.positionID,
                action: .decreaseMargin,
            )
        }
        self.markingPercentages = markingPercentages
        self.markingAmounts = markingPercentages.map { percentage in
            let value = positionViewModel.decimalMargin * percentage
            return if value > 0.01 {
                Input(mode: .byAmount, value: value).value
            } else {
                value
            }
        }
        let nib = R.nib.reduceToPerpsPositionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presentationController?.delegate = self
        
        var tags: [String: String] = [:]
        tags["source"] = UserOperationAnalytics.tradeSource?.rawValue
        
        titleView.iconView.setIcon(tokenIconURL: marketViewModel.iconURL)
        switch target {
        case .margin:
            reporter.report(event: .tradePerpsReduceMarginStart, tags: tags)
            titleView.titleLabel.text = R.string.localizable.perps_reduce_margin_title(
                positionViewModel.side.localizedName,
                marketViewModel.market.tokenSymbol
            )
            targetTitleLabel.text = R.string.localizable.margin()
        case .position:
            assertionFailure("Not ready")
        }
        titleView.subtitleLabel.attributedText = {
            let currentPrice = marketViewModel.price
            let text = NSMutableAttributedString(
                string: R.string.localizable.auto_close_subtitle_after_open(
                    positionViewModel.entryPrice,
                    currentPrice
                ),
                attributes: [.foregroundColor: R.color.text_quaternary()!]
            )
            if let range = text.string.range(of: positionViewModel.entryPrice) {
                text.setAttributes(
                    [.foregroundColor: R.color.text_tertiary()!],
                    range: NSRange(range, in: text.string)
                )
            }
            if let range = text.string.range(of: currentPrice, options: .backwards) {
                text.setAttributes(
                    [.foregroundColor: R.color.text_tertiary()!],
                    range: NSRange(range, in: text.string)
                )
            }
            return text
        }()
        titleView.closeButton.addTarget(
            self,
            action: #selector(cancel(_:)),
            for: .touchUpInside
        )
        
        inputBackgroundView.layer.cornerRadius = 8
        inputBackgroundView.layer.masksToBounds = true
        valueTextField.leftView = leftSignLabel
        valueTextField.rightView = rightSignLabel
        valueTextField.delegate = self
        valueTextField.placeholder = Decimal(0).formatted(
            absoluteAmountUserInputSimulationFormatter
        )
        swapValueDisplayButton.addTarget(
            self,
            action: #selector(swapValueDisplay(_:)),
            for: .touchUpInside
        )
        updateValueTextFieldAccessories()
        updateValueViews(updatingValueTextField: false)
        swapValueDisplayImageView.image = R.image.swap_transposition()!
            .withRenderingMode(.alwaysTemplate)
        for _ in markingPercentages {
            var config: UIButton.Configuration = .plain()
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 12, weight: .medium)
                )
                return outgoing
            }
            config.baseForegroundColor = R.color.text_secondary()
            config.contentInsets = .zero
            let button = UIButton(configuration: config)
            button.addTarget(
                self,
                action: #selector(selectMarking(_:)),
                for: .touchUpInside
            )
            markingStackView.addArrangedSubview(button)
            markingButtons.append(button)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
        }
        updateMarkingButtons()
        
        let infoLabels: [UILabel] = [
            targetTitleLabel,
            targetContentLabel,
            liquidationPriceTitleLabel,
            liquidationPriceContentLabel,
        ]
        for label in infoLabels {
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
        liquidationPriceTitleLabel.text = R.string.localizable.liquidation_price()
        liquidationPriceActivityIndicator.style = .custom(diameter: 10, lineWidth: 2)
        evaluateReducingAmount()
        
        actionWrapperView.snp.makeConstraints { make in
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }
        if var config = cancelButton.configuration {
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.preferredFont(forTextStyle: .callout)
                return outgoing
            }
            config.title = R.string.localizable.cancel()
            cancelButton.configuration = config
        }
        cancelButton.titleLabel?.adjustsFontForContentSizeCategory = true
        if var config = reduceButton.configuration {
            config.baseBackgroundColor = MarketColor.rising.uiColor
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.preferredFont(forTextStyle: .callout)
                return outgoing
            }
            config.title = R.string.localizable.perps_reduce_margin()
            reduceButton.configuration = config
        }
        reduceButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        valueTextField.becomeFirstResponder()
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        switch ScreenWidth(size: view.bounds.size) {
        case .short:
            valueTextField.font = .systemFont(ofSize: 24, weight: .semibold)
        case .medium:
            valueTextField.font = .systemFont(ofSize: 36, weight: .semibold)
        case .long:
            valueTextField.font = .systemFont(ofSize: 48, weight: .semibold)
        }
        for label in [leftSignLabel, rightSignLabel] {
            label.font = valueTextField.font
            label.textColor = valueTextField.textColor
        }
    }
    
    @IBAction func valueEditingChanged(_ sender: UITextField) {
        let value = Decimal(string: sender.text ?? "", locale: .current) ?? 0
        input = Input(
            mode: amountDisplay,
            value: amountDisplay == .byPercentage ? value / 100 : value,
        )
        updateValueViews(updatingValueTextField: false)
        evaluateReducingAmount()
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        let percentage = Decimal(Double(sender.value * 100).rounded()) / 100
        switch amountDisplay {
        case .byAmount:
            input = Input(
                mode: .byAmount,
                value: positionViewModel.decimalMargin * percentage,
            )
            updateValueViews(updatingValueTextField: true)
            evaluateReducingAmount()
        case .byPercentage:
            inputPercentage(percentage)
        }
    }
    
    @IBAction func decreaseMultiplierBy1(_ sender: Any) {
        adjustValue(by: -1)
    }
    
    @IBAction func increaseMultiplierBy1(_ sender: Any) {
        adjustValue(by: 1)
    }
    
    @IBAction func decreaseMultiplierBy5(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            adjustValue(by: -5)
        }
    }
    
    @IBAction func increaseMultiplierBy5(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            adjustValue(by: 5)
        }
    }
    
    @IBAction func introducePositionSize(_ sender: Any) {
        let manual = PerpsManual.viewController(initialPage: .size)
        present(manual, animated: true)
        switch target {
        case .margin:
            reporter.report(
                event: .tradePerpsGuide,
                tags: ["source": "perps_reduce_margin_size"]
            )
        case .position:
            assertionFailure("Not ready")
        }
    }
    
    @IBAction func introduceLiquidationPrice(_ sender: Any) {
        let manual = PerpsManual.viewController(initialPage: .liquidation)
        present(manual, animated: true)
        switch target {
        case .margin:
            reporter.report(
                event: .tradePerpsGuide,
                tags: ["source": "perps_reduce_margin_liquidation"]
            )
        case .position:
            assertionFailure("Not ready")
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        liquidationPriceRequester.cancelLastRequest()
        presentingViewController?.dismiss(animated: true)
        reporter.report(event: .tradePerpsReduceMarginCancel)
    }
    
    @IBAction func reduce(_ sender: Any) {
        guard absoluteAmount > 0, validatedAmount == absoluteAmount else {
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
    
    @objc private func swapValueDisplay(_ sender: Any) {
        amountDisplay = switch amountDisplay {
        case .byAmount:
                .byPercentage
        case .byPercentage:
                .byAmount
        }
        updateValueTextFieldAccessories()
        updateValueViews(updatingValueTextField: true)
        updateMarkingButtons()
    }
    
    @objc private func selectMarking(_ sender: UIButton) {
        guard let index = markingButtons.firstIndex(of: sender) else {
            return
        }
        switch amountDisplay {
        case .byAmount:
            input = Input(mode: .byAmount, value: markingAmounts[index])
            updateValueViews(updatingValueTextField: true)
            evaluateReducingAmount()
        case .byPercentage:
            inputPercentage(markingPercentages[index])
        }
    }
    
}

extension ReduceToPerpsPositionViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        false
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        
    }
    
}

extension ReduceToPerpsPositionViewController: UITextFieldDelegate {
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String,
    ) -> Bool {
        let text = textField.text ?? ""
        guard let range = Range(range, in: text) else {
            return false
        }
        let input = text.replacingCharacters(in: range, with: string)
        guard !input.isEmpty else {
            return true
        }
        guard input.count <= 40 else {
            return false
        }
        let separator = Locale.current.decimalSeparator ?? "."
        let parts = input.components(separatedBy: separator)
        let isPercentage = amountDisplay == .byPercentage
        guard parts.count <= (isPercentage ? 1 : 2),
              parts.allSatisfy({ $0.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains) })
        else {
            return false
        }
        if parts.count == 2, parts[1].count > 2 {
            return false
        }
        return input == separator || Decimal(string: input, locale: .current) != nil
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        updateValueViews(updatingValueTextField: true)
    }
    
}

extension ReduceToPerpsPositionViewController {
    
    private enum AmountDisplay {
        case byAmount
        case byPercentage
    }
    
    private struct Input {
        
        let mode: AmountDisplay
        
        // Absolute value for percentages, like 0.1 for 10%
        let value: Decimal
        
        init(mode: AmountDisplay, value: Decimal) {
            self.mode = mode
            self.value = withUnsafePointer(to: value) { value in
                var roundedValue: Decimal = 0
                switch mode {
                case .byAmount:
                    NSDecimalRound(&roundedValue, value, 2, .down)
                case .byPercentage:
                    NSDecimalRound(&roundedValue, value, 2, .plain)
                }
                return roundedValue
            }
        }
        
    }
    
    private enum LiquidationPrice {
        case invalid
        case busy
        case valid(price: Decimal)
    }
    
    private func updateValueTextFieldAccessories() {
        let sign: String
        let position: SignPosition
        switch amountDisplay {
        case .byAmount:
            sign = "$"
            position = .currency
            valueTextField.keyboardType = .decimalPad
        case .byPercentage:
            sign = "%"
            position = .percentage
            valueTextField.keyboardType = .numberPad
        }
        switch position {
        case .left:
            leftSignLabel.text = sign
            rightSignLabel.text = nil
            valueTextField.leftViewMode = .always
            valueTextField.rightViewMode = .never
        case .right:
            leftSignLabel.text = nil
            rightSignLabel.text = sign
            valueTextField.leftViewMode = .never
            valueTextField.rightViewMode = .always
        }
        leftSignLabel.sizeToFit()
        rightSignLabel.sizeToFit()
        valueTextField.invalidateIntrinsicContentSize()
        valueTextField.setNeedsLayout()
    }
    
    private func updateMarkingButtons() {
        for (index, button) in markingButtons.enumerated() {
            guard var config = button.configuration else {
                continue
            }
            config.title = switch amountDisplay {
            case .byAmount:
                markingAmounts[index].formatted(
                    Decimal.FormatStyle.Currency
                        .currency(code: "USD")
                        .presentation(.narrow)
                        .precision(.fractionLength(0...8))
                        .rounded(rule: .towardZero)
                )
            case .byPercentage:
                PercentageFormatter.string(
                    from: markingPercentages[index],
                    format: .pretty,
                    sign: .never
                )
            }
            button.configuration = config
        }
    }
    
    private func inputPercentage(_ percentage: Decimal) {
        let percentage = min(1, max(0, percentage))
        input = Input(mode: .byPercentage, value: percentage)
        updateValueViews(updatingValueTextField: true)
        evaluateReducingAmount()
    }
    
    private func adjustValue(by change: Int) {
        switch amountDisplay {
        case .byPercentage:
            let percentage = Input(mode: .byPercentage, value: percentage).value
            inputPercentage(percentage + Decimal(change) / 100)
        case .byAmount:
            let value = min(
                max(0, positionViewModel.decimalMargin),
                max(0, absoluteAmount + Decimal(change))
            )
            input = Input(mode: .byAmount, value: value)
            updateValueViews(updatingValueTextField: true)
            evaluateReducingAmount()
        }
    }
    
    private func updateValueViews(updatingValueTextField: Bool) {
        switch amountDisplay {
        case .byAmount:
            if updatingValueTextField {
                valueTextField.text = if absoluteAmount == 0 {
                    nil
                } else {
                    absoluteAmount.formatted(
                        absoluteAmountUserInputSimulationFormatter
                    )
                }
            }
            alternativeValueLabel.text = PercentageFormatter.string(
                from: percentage,
                format: .pretty,
                sign: .never
            )
        case .byPercentage:
            if updatingValueTextField {
                valueTextField.text = if percentage == 0 {
                    nil
                } else {
                    (percentage * 100).formatted(
                        percentageUserInputSimulationFormatter
                    )
                }
            }
            alternativeValueLabel.text = CurrencyFormatter.localizedString(
                from: absoluteAmount,
                format: .fiatMoneyPretty,
                sign: .never,
                symbol: .dollarSign
            )
        }
        slider.value = NSDecimalNumber(decimal: min(1, max(0, percentage))).floatValue
        slider.isEnabled = positionViewModel.decimalMargin > 0
        decreaseMultiplierButton.isEnabled = absoluteAmount > 0
        increaseMultiplierButton.isEnabled = absoluteAmount < positionViewModel.decimalMargin
    }
    
    private func evaluateReducingAmount() {
        let reducingAmount = absoluteAmount
        validatedAmount = nil
        liquidationPriceRequester.cancelLastRequest()
        showError(description: nil)
        switch target {
        case .margin:
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
                targetContentLabel.text = before + " → " + after
            } else {
                targetContentLabel.text = before
            }
        case .position:
            assertionFailure("Not ready")
        }
        
        guard reducingAmount > 0 else {
            show(liquidationPrice: .invalid)
            return
        }
        show(liquidationPrice: .busy)
        liquidationPriceRequester.request(
            amount: reducingAmount
        ) { [weak self] price in
            guard let self else {
                return
            }
            self.validatedAmount = reducingAmount
            self.showError(description: nil)
            self.show(liquidationPrice: .valid(price: price))
        } onFailure: { [weak self] error in
            guard let self else {
                return
            }
            self.show(liquidationPrice: .invalid)
            if case let .response(error) = error as? MixinAPIError,
               case .exceedsMaxRemovableMargin = error,
               case let .string(value) = error.extra?.value(at: ["available_margin"]),
               let decimalValue = Decimal(string: value, locale: .enUSPOSIX)
            {
                self.showMaximumRemovable(decimalValue)
            } else {
                self.showError(description: error.localizedDescription)
            }
        }
    }
    
    private func show(liquidationPrice: LiquidationPrice) {
        switch liquidationPrice {
        case .invalid:
            liquidationPriceActivityIndicator.stopAnimating()
            validatedAmount = nil
            liquidationPriceContentLabel.text = liquidationPriceBeforeReducing
            liquidationPriceContentLabel.alpha = 1
            reduceButton.isEnabled = false
        case .busy:
            liquidationPriceActivityIndicator.startAnimating()
            liquidationPriceContentLabel.alpha = 0
            reduceButton.isEnabled = false
        case let .valid(price):
            liquidationPriceActivityIndicator.stopAnimating()
            liquidationPriceContentLabel.text = price.formatted(
                marketViewModel.userDisplayPriceFormatStyle
            )
            liquidationPriceContentLabel.alpha = 1
            reduceButton.isEnabled = true
        }
    }
    
    private func showMaximumRemovable(_ amount: Decimal) {
        let value: String
        switch amountDisplay {
        case .byAmount:
            value = CurrencyFormatter.localizedString(
                from: amount,
                format: .precision,
                sign: .never,
                symbol: .dollarSign
            )
        case .byPercentage:
            let margin = positionViewModel.decimalMargin
            value = PercentageFormatter.string(
                from: margin > 0 ? amount / margin : 0,
                format: .pretty,
                sign: .never
            )
        }
        showError(description: R.string.localizable.max_removable(value))
    }
    
    private func showError(description: String?) {
        if let description {
            errorDescriptionLabel.text = description
            errorDescriptionLabel.alpha = 1
        } else {
            errorDescriptionLabel.alpha = 0
        }
    }
    
}
