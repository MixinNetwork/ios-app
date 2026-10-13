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
    @IBOutlet weak var errorDescriptionButton: UIButton!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var markingContainerView: UIView!
    
    @IBOutlet weak var firstDescriptionTitleLabel: UILabel!
    @IBOutlet weak var firstDescriptionContentLabel: UILabel!
    
    @IBOutlet weak var secondDescriptionTitleLabel: UILabel!
    @IBOutlet weak var secondDescriptionContentLabel: UILabel!
    @IBOutlet weak var secondDescriptionInfoView: UIImageView!
    @IBOutlet weak var secondDescriptionInfoButton: UIButton!
    @IBOutlet weak var secondDescriptionActivityIndicator: ActivityIndicatorView!
    
    @IBOutlet weak var thirdDescriptionView: UIStackView!
    @IBOutlet weak var thirdDescriptionTitleLabel: UILabel!
    @IBOutlet weak var thirdDescriptionContentLabel: UILabel!
    @IBOutlet weak var thirdDescriptionInfoView: UIImageView!
    @IBOutlet weak var thirdDescriptionInfoButton: UIButton!
    
    @IBOutlet weak var actionWrapperView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var reduceButton: UIButton!
    
    private let wallet: Wallet
    private let target: PerpPositionAdjustmentTarget
    private let liquidationPriceRequester: EditPerpsPositionLiquidationPriceRequester?
    private let leftSignLabel = UILabel()
    private let rightSignLabel = UILabel()
    private let valuePlaceholderColor = R.color.text_quaternary()!
    private let markingPercentages: [Decimal]
    
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
    
    private var marketViewModel: PerpetualMarketViewModel
    private var positionViewModel: PerpetualPositionViewModel
    private var liquidationPriceBeforeReducing: String
    private var markingAmounts: [Decimal]
    private var totalAmount: Decimal
    
    private var markingButtons: [UIButton] = []
    private var input = Input(mode: .byPercentage, value: 0)
    private var amountDisplay: AmountDisplay
    
    // Dollars for margin reduction; token quantity for position reduction.
    private var validatedReductionValue: Decimal?
    
    private var maximumRemovableAmount: Decimal?
    
    private var absoluteAmount: Decimal {
        switch input.mode {
        case .byAmount:
            return input.value
        case .byPercentage:
            var amount = totalAmount * input.value
            switch target {
            case .margin:
                var result = Decimal()
                NSDecimalRound(&result, &amount, Int(MixinToken.internalPrecision), .down)
                return result
            case .position:
                return amount
            }
        }
    }
    
    private var percentage: Decimal {
        switch input.mode {
        case .byPercentage:
            input.value
        case .byAmount:
            totalAmount > 0 ? input.value / totalAmount : 0
        }
    }
    
    init(
        wallet: Wallet,
        reducing target: PerpPositionAdjustmentTarget,
        marketViewModel: PerpetualMarketViewModel,
        positionViewModel: PerpetualPositionViewModel,
    ) {
        let markingPercentages: [Decimal] = [0, 0.25, 0.5, 0.75, 1]
        let totalAmount: Decimal = switch target {
        case .margin:
            positionViewModel.decimalMargin
        case .position:
            positionViewModel.decimalQuantity * positionViewModel.position.decimalMarkPrice
        }
        
        self.wallet = wallet
        self.target = target
        self.marketViewModel = marketViewModel
        self.positionViewModel = positionViewModel
        switch target {
        case .margin:
            self.liquidationPriceRequester = EditPerpsPositionLiquidationPriceRequester(
                positionID: positionViewModel.position.positionID,
                action: .decreaseMargin,
            )
        case .position:
            self.liquidationPriceRequester = nil
        }
        self.markingPercentages = markingPercentages
        self.totalAmount = totalAmount
        self.markingAmounts = Input.markingAmounts(
            amount: totalAmount,
            percentages: markingPercentages,
        )
        self.liquidationPriceBeforeReducing = positionViewModel.decimalLiquidationPrice?.formatted(
            marketViewModel.userDisplayPriceFormatStyle
        ) ?? "-"
        self.amountDisplay = AppGroupUserDefaults.Wallet.reducePerpsPositionAmountDisplay
            .flatMap(AmountDisplay.init(rawValue:))
        ?? .byPercentage
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
            firstDescriptionTitleLabel.text = R.string.localizable.margin()
            secondDescriptionTitleLabel.text = R.string.localizable.liquidation_price()
            secondDescriptionInfoView.isHidden = false
            thirdDescriptionView.isHidden = true
            thirdDescriptionInfoView.isHidden = true
            thirdDescriptionInfoButton.isHidden = true
        case .position:
            reporter.report(event: .tradePerpsReducePositionStart, tags: tags)
            titleView.titleLabel.text = R.string.localizable.perps_close_position_title(
                positionViewModel.side.localizedName,
                marketViewModel.market.tokenSymbol
            )
            firstDescriptionTitleLabel.text = R.string.localizable.estimated_receive()
            firstDescriptionContentLabel.textColor = R.color.text()!
            secondDescriptionTitleLabel.text = R.string.localizable.margin()
            secondDescriptionInfoView.isHidden = true
            secondDescriptionInfoButton.isHidden = true
            thirdDescriptionView.isHidden = false
            thirdDescriptionInfoView.isHidden = false
            thirdDescriptionInfoButton.isHidden = false
            thirdDescriptionTitleLabel.text = R.string.localizable.fee()
            thirdDescriptionContentLabel.textColor = R.color.text()!
        }
        updateSubtitle()
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
        valueTextField.attributedPlaceholder = NSAttributedString(
            string: Decimal(0).formatted(absoluteAmountUserInputSimulationFormatter),
            attributes: [.foregroundColor: valuePlaceholderColor],
        )
        swapValueDisplayButton.addTarget(
            self,
            action: #selector(swapValueDisplay(_:)),
            for: .touchUpInside
        )
        updateValueTextFieldAccessories()
        updateValueViews(updatingValueTextField: false)
        if var config = errorDescriptionButton.configuration {
            config.titleAlignment = .center
            config.titleLineBreakMode = .byTruncatingTail
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = .preferredFont(forTextStyle: .caption1)
                return outgoing
            }
            errorDescriptionButton.configuration = config
        }
        if let label = errorDescriptionButton.titleLabel {
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
        }
        swapValueDisplayImageView.image = R.image.swap_transposition()!
            .withRenderingMode(.alwaysTemplate)
        for (index, percentage) in markingPercentages.enumerated() {
            var config: UIButton.Configuration = .plain()
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 12, weight: .medium)
                )
                return outgoing
            }
            config.baseForegroundColor = R.color.text_tertiary()
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
            let button = UIButton(configuration: config)
            button.addTarget(
                self,
                action: #selector(selectMarking(_:)),
                for: .touchUpInside
            )
            markingContainerView.addSubview(button)
            button.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
            }
            switch index {
            case 0:
                button.configuration?.contentInsets.leading = 16
                button.snp.makeConstraints { make in
                    make.leading.equalToSuperview()
                }
            case markingPercentages.count - 1:
                button.configuration?.contentInsets.trailing = 16
                button.snp.makeConstraints { make in
                    make.trailing.equalToSuperview()
                }
            default:
                let positionGuide = UILayoutGuide()
                markingContainerView.addLayoutGuide(positionGuide)
                positionGuide.snp.makeConstraints { make in
                    make.leading.equalTo(slider.snp.leading)
                    make.width.equalTo(slider.snp.width)
                        .multipliedBy(CGFloat(NSDecimalNumber(decimal: percentage).doubleValue))
                    make.top.bottom.equalTo(markingContainerView)
                }
                button.snp.makeConstraints { make in
                    make.centerX.equalTo(positionGuide.snp.trailing)
                }
            }
            markingButtons.append(button)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
        }
        updateMarkingButtons()
        
        let infoLabels: [UILabel] = [
            firstDescriptionTitleLabel,
            firstDescriptionContentLabel,
            secondDescriptionTitleLabel,
            secondDescriptionContentLabel,
            thirdDescriptionTitleLabel,
            thirdDescriptionContentLabel,
        ]
        for label in infoLabels {
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
        secondDescriptionActivityIndicator.style = .custom(diameter: 10, lineWidth: 2)
        updateDescriptions(requestLiquidationPrice: false)
        
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
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.preferredFont(forTextStyle: .callout)
                return outgoing
            }
            config.title = switch target {
            case .margin:
                R.string.localizable.perps_reduce_margin()
            case .position:
                R.string.localizable.perps_reduce_position()
            }
            reduceButton.configuration = config
        }
        reduceButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadMarket(_:)),
            name: PerpsMarketDAO.marketsDidUpdateNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadPosition),
            name: PerpsPositionDAO.perpsPositionDidChangeNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil,
        )
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
        }
    }
    
    @IBAction func valueEditingChanged(_ sender: UITextField) {
        let value = Decimal(string: sender.text ?? "", locale: .current) ?? 0
        input = Input(
            mode: amountDisplay,
            value: amountDisplay == .byPercentage ? value / 100 : value,
        )
        updateValueViews(updatingValueTextField: false)
        updateDescriptions(requestLiquidationPrice: true)
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        let percentage = Decimal(Double(sender.value * 100).rounded()) / 100
        switch target {
        case .margin:
            switch amountDisplay {
            case .byAmount:
                input = Input(
                    mode: .byAmount,
                    value: totalAmount * percentage,
                )
                updateValueViews(updatingValueTextField: true)
                updateDescriptions(requestLiquidationPrice: true)
            case .byPercentage:
                inputPercentage(percentage)
            }
        case .position:
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
    
    @IBAction func introduceSecondDescription(_ sender: Any) {
        switch target {
        case .margin:
            let manual = PerpsManual.viewController(initialPage: .liquidation)
            present(manual, animated: true)
            reporter.report(
                event: .tradePerpsGuide,
                tags: ["source": "perps_reduce_margin_liquidation"]
            )
        case .position:
            break
        }
    }
    
    @IBAction func introduceThirdDescription(_ sender: Any) {
        switch target {
        case .margin:
            break
        case .position:
            let manual = PerpsManual.viewController(initialPage: .tradingFee)
            present(manual, animated: true)
            reporter.report(
                event: .tradePerpsGuide,
                tags: ["source": "perps_reduce_position_fee"]
            )
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        liquidationPriceRequester?.cancelLastRequest()
        presentingViewController?.dismiss(animated: true)
        switch target {
        case .margin:
            reporter.report(event: .tradePerpsReduceMarginCancel)
        case .position:
            reporter.report(event: .tradePerpsReducePositionCancel)
        }
    }
    
    @IBAction func inputMaximumRemovable(_ sender: UIButton) {
        guard let maximumRemovableAmount else {
            return
        }
        input = Input(mode: .byAmount, value: maximumRemovableAmount)
        updateValueTextFieldAccessories()
        updateValueViews(updatingValueTextField: true)
        updateMarkingButtons()
        updateDescriptions(requestLiquidationPrice: true)
    }
    
    @IBAction func reduce(_ sender: Any) {
        switch target {
        case .margin:
            guard absoluteAmount > 0, validatedReductionValue == absoluteAmount else {
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
        case .position:
            guard let reducingQuantity = validatedReductionValue else {
                return
            }
            let preview = ClosePerpetualPositionPreviewViewController(
                reducing: positionViewModel,
                quantity: reducingQuantity,
                market: marketViewModel.market,
                onDismissAfterSuccess: { [weak self] in
                    self?.presentingViewController?.dismiss(animated: true)
                },
            )
            reporter.report(event: .tradePerpsReducePositionPreview)
            valueTextField.resignFirstResponder()
            present(preview, animated: true)
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        guard viewIfLoaded?.window != nil, presentedViewController == nil else {
            return
        }
        valueTextField.becomeFirstResponder()
    }
    
    @objc private func reloadMarket(_ notification: Notification) {
        guard
            let market = notification.userInfo?[PerpsMarketDAO.UserInfoKey.market] as? PerpetualMarket,
            market.marketID == marketViewModel.market.marketID
        else {
            return
        }
        let viewModel = PerpetualMarketViewModel(market: market)
        marketViewModel = viewModel
        updateSubtitle()
        switch target {
        case .margin:
            break
        case .position:
            updateAmounts()
            updateValueViews(updatingValueTextField: !valueTextField.isFirstResponder || input.mode != amountDisplay)
            updateMarkingButtons()
            updateDescriptions(requestLiquidationPrice: false)
        }
    }
    
    @objc private func reloadPosition() {
        let positionID = positionViewModel.position.positionID
        DispatchQueue.global().async { [weak self, wallet] in
            guard let position = PerpsPositionDAO.shared.position(positionID: positionID) else {
                return
            }
            let viewModel = PerpetualPositionViewModel(wallet: wallet, position: position)
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.positionViewModel = viewModel
                self.updateAmounts()
                self.liquidationPriceBeforeReducing = viewModel.decimalLiquidationPrice?.formatted(
                    self.marketViewModel.userDisplayPriceFormatStyle
                ) ?? "-"
                self.updateSubtitle()
                self.updateValueViews(updatingValueTextField: !self.valueTextField.isFirstResponder || self.input.mode != self.amountDisplay)
                self.updateMarkingButtons()
                self.updateDescriptions(requestLiquidationPrice: true)
            }
        }
    }
    
    @objc private func swapValueDisplay(_ sender: Any) {
        amountDisplay = switch amountDisplay {
        case .byAmount:
                .byPercentage
        case .byPercentage:
                .byAmount
        }
        AppGroupUserDefaults.Wallet.reducePerpsPositionAmountDisplay = amountDisplay.rawValue
        updateValueTextFieldAccessories()
        updateValueViews(updatingValueTextField: true)
        updateMarkingButtons()
    }
    
    @objc private func selectMarking(_ sender: UIButton) {
        guard let index = markingButtons.firstIndex(of: sender) else {
            return
        }
        switch target {
        case .margin:
            break
        case .position:
            inputPercentage(markingPercentages[index])
            return
        }
        switch amountDisplay {
        case .byAmount:
            input = Input(mode: .byAmount, value: markingAmounts[index])
            updateValueViews(updatingValueTextField: true)
            updateDescriptions(requestLiquidationPrice: true)
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
    
    private enum AmountDisplay: Int {
        case byAmount       = 0
        case byPercentage   = 1
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
        
        static func markingAmounts(
            amount: Decimal,
            percentages: [Decimal]
        ) -> [Decimal] {
            percentages.map { percentage in
                let value = amount * percentage
                return if value > 0.01 {
                    Input(mode: .byAmount, value: value).value
                } else {
                    value
                }
            }
        }
        
    }
    
    private enum LiquidationPrice {
        case invalid
        case busy
        case valid(price: Decimal)
    }
    
    private func updateSubtitle() {
        let currentPrice = marketViewModel.localizedLastPrice
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
        titleView.subtitleLabel.attributedText =  text
    }
    
    private func updateValueTextFieldAccessories() {
        let sign: String
        let position: SignPosition
        switch amountDisplay {
        case .byAmount:
            sign = "$"
            position = .currency
        case .byPercentage:
            sign = "%"
            position = .percentage
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
    
    private func updateAmounts() {
        totalAmount = switch target {
        case .margin:
            positionViewModel.decimalMargin
        case .position:
            positionViewModel.decimalQuantity * positionViewModel.position.decimalMarkPrice
        }
        markingAmounts = Input.markingAmounts(
            amount: totalAmount,
            percentages: markingPercentages,
        )
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
        updateDescriptions(requestLiquidationPrice: true)
    }
    
    private func adjustValue(by change: Int) {
        switch amountDisplay {
        case .byPercentage:
            let percentage = Input(mode: .byPercentage, value: percentage).value
            inputPercentage(percentage + Decimal(change) / 100)
        case .byAmount:
            let value = min(
                max(0, totalAmount),
                max(0, absoluteAmount + Decimal(change))
            )
            switch target {
            case .margin:
                break
            case .position:
                if value == totalAmount, totalAmount > 0 {
                    inputPercentage(1)
                    return
                }
            }
            input = Input(mode: .byAmount, value: value)
            updateValueViews(updatingValueTextField: true)
            updateDescriptions(requestLiquidationPrice: true)
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
        let signColor = valueTextField.hasText ? valueTextField.textColor : valuePlaceholderColor
        leftSignLabel.textColor = signColor
        rightSignLabel.textColor = signColor
        slider.value = NSDecimalNumber(decimal: min(1, max(0, percentage))).floatValue
        decreaseMultiplierButton.isEnabled = absoluteAmount > 0
        increaseMultiplierButton.isEnabled = absoluteAmount < totalAmount
    }
    
    private func updateDescriptions(requestLiquidationPrice: Bool) {
        let reducingAmount = absoluteAmount
        if requestLiquidationPrice || reducingAmount <= 0 {
            validatedReductionValue = nil
            liquidationPriceRequester?.cancelLastRequest()
            showError(description: nil)
        }
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
                firstDescriptionContentLabel.text = PerpPositionAdjustment.change(from: before, to: after)
            } else {
                firstDescriptionContentLabel.text = before
            }
        case .position:
            let markPrice = positionViewModel.position.decimalMarkPrice
            validatedReductionValue = {
                let current = abs(positionViewModel.decimalQuantity)
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
                return roundedQuantity
            }()
            firstDescriptionContentLabel.text = "-"
            secondDescriptionContentLabel.text = "-"
            thirdDescriptionContentLabel.text = "-"
            secondDescriptionContentLabel.alpha = 1
            secondDescriptionActivityIndicator.stopAnimating()
            reduceButton.isEnabled = false
            showError(description: nil)
            if let reducingQuantity = validatedReductionValue {
                let proportion = reducingQuantity / positionViewModel.decimalQuantity
                let margin = positionViewModel.decimalMargin * proportion
                let pnl = positionViewModel.position.decimalUnrealizedPnL * proportion
                secondDescriptionContentLabel.attributedText = {
                    let description = NSMutableAttributedString(
                        string: CurrencyFormatter.localizedString(
                            from: margin,
                            format: .precision,
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
                            format: .precision,
                            sign: .always,
                            symbol: .dollarSign,
                        ),
                        attributes: [.foregroundColor: positionViewModel.pnlColor.uiColor],
                    ))
                    return description
                }()
                if let estimatedCloseFee = positionViewModel.position.decimalEstimatedCloseFee {
                    let fee = estimatedCloseFee * proportion
                    firstDescriptionContentLabel.text = CurrencyFormatter.localizedString(
                        from: margin + pnl - fee,
                        format: .fiatMoneyPretty,
                        sign: .whenNegative,
                        symbol: .dollarSign,
                    )
                    thirdDescriptionContentLabel.text = fee.formatted(PerpetualOrder.feeFormatStyle)
                    thirdDescriptionView.isHidden = false
                } else {
                    thirdDescriptionView.isHidden = true
                }
                reduceButton.isEnabled = true
            } else if input.value != 0 {
                showError(description: R.string.localizable.perps_reduce_invalid_quantity())
            }
            return
        }
        
        guard reducingAmount > 0 else {
            show(liquidationPrice: .invalid)
            return
        }
        if requestLiquidationPrice, let liquidationPriceRequester {
            show(liquidationPrice: .busy)
            liquidationPriceRequester.request(
                amount: reducingAmount,
                symbol: nil,
            ) { [weak self] price in
                guard let self else {
                    return
                }
                self.validatedReductionValue = reducingAmount
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
    
    private func show(liquidationPrice: LiquidationPrice) {
        switch liquidationPrice {
        case .invalid:
            secondDescriptionActivityIndicator.stopAnimating()
            validatedReductionValue = nil
            secondDescriptionContentLabel.text = liquidationPriceBeforeReducing
            secondDescriptionContentLabel.alpha = 1
            reduceButton.isEnabled = false
        case .busy:
            secondDescriptionActivityIndicator.startAnimating()
            secondDescriptionContentLabel.alpha = 0
            reduceButton.isEnabled = false
        case let .valid(price):
            secondDescriptionActivityIndicator.stopAnimating()
            let after = price.formatted(
                marketViewModel.userDisplayPriceFormatStyle
            )
            secondDescriptionContentLabel.text = PerpPositionAdjustment.change(
                from: liquidationPriceBeforeReducing,
                to: after,
            )
            secondDescriptionContentLabel.alpha = 1
            reduceButton.isEnabled = true
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
        errorDescriptionButton.isEnabled = false
        if let description {
            errorDescriptionButton.configuration?.title = description
            errorDescriptionButton.alpha = 1
        } else {
            errorDescriptionButton.alpha = 0
        }
    }
    
}
