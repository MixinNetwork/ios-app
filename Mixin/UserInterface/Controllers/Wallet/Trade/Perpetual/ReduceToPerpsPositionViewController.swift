import UIKit
import MixinServices

class ReduceToPerpsPositionViewController: UIViewController {
    
    @IBOutlet weak var titleView: EditPerpsPositionTitleView!
    
    @IBOutlet weak var contentView: UIView!
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
    @IBOutlet private weak var descriptionStackView: UIStackView!
    
    @IBOutlet weak var actionWrapperView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var confirmButton: UIButton!
    
    let wallet: Wallet
    
    var marketViewModel: PerpetualMarketViewModel
    var positionViewModel: PerpetualPositionViewModel
    
    private(set) var input: Input
    private(set) var amountDisplay: AmountDisplay
    
    var totalAmount: Decimal {
        preconditionFailure("Must override")
    }
    
    var absoluteAmount: Decimal {
        switch input.mode {
        case .byAmount:
            input.value
        case .byPercentage:
            totalAmount * input.value
        }
    }
    
    var percentage: Decimal {
        switch input.mode {
        case .byPercentage:
            input.value
        case .byAmount:
            totalAmount > 0 ? input.value / totalAmount : 0
        }
    }
    
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
    
    private var markingButtons: [UIButton] = []
    
    private var markingAmounts: [Decimal] {
        Input.markingAmounts(amount: totalAmount, percentages: markingPercentages)
    }
    
    init(
        wallet: Wallet,
        marketViewModel: PerpetualMarketViewModel,
        positionViewModel: PerpetualPositionViewModel,
        initialPercentage: Decimal,
    ) {
        self.wallet = wallet
        self.input = Input(mode: .byPercentage, value: initialPercentage)
        self.marketViewModel = marketViewModel
        self.positionViewModel = positionViewModel
        self.markingPercentages = [0, 0.25, 0.5, 0.75, 1]
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
        
        titleView.iconView.setIcon(tokenIconURL: marketViewModel.iconURL)
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
        updateValueViews(updatingValueTextField: true)
        if var config = errorDescriptionButton.configuration {
            config.titleAlignment = .center
            config.titleLineBreakMode = .byTruncatingTail
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
            config.attributedTitle = AttributedString(
                string: PercentageFormatter.string(
                    from: percentage,
                    format: .pretty,
                    sign: .never
                ),
                scalingByFontSize: 12,
                weight: .medium
            )
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
        if var config = confirmButton.configuration {
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.preferredFont(forTextStyle: .callout)
                return outgoing
            }
            config.title = R.string.localizable.confirm()
            confirmButton.configuration = config
        }
        confirmButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
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
        updateDescriptions(refreshValidation: true)
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        let percentage = Decimal(Double(sender.value * 100).rounded()) / 100
        selectReduction(percentage: percentage, amount: totalAmount * percentage)
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
    
    @IBAction func cancel(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @IBAction func reduce(_ sender: Any) {
        
    }
    
    func addDescription(
        title: String,
        alignment: UIStackView.Alignment,
        infoAction: Selector?,
        showsActivityIndicator: Bool,
    ) -> DescriptionRow {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = R.color.text_tertiary()
        titleLabel.setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
        
        let contentLabel = UILabel()
        contentLabel.text = "-"
        contentLabel.textColor = R.color.text_secondary()
        contentLabel.textAlignment = .right
        contentLabel.numberOfLines = 0
        contentLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for label in [titleLabel, contentLabel] {
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
        
        let stackView = UIStackView()
        stackView.alignment = alignment
        stackView.spacing = 4
        stackView.addArrangedSubview(titleLabel)
        descriptionStackView.addArrangedSubview(stackView)
        
        let infoButton: UIButton?
        if let infoAction {
            let infoView = UIImageView(image: R.image.info())
            infoView.contentMode = .scaleAspectFit
            stackView.addArrangedSubview(infoView)
            infoView.snp.makeConstraints { make in
                make.width.equalTo(16)
                make.height.equalTo(16).priority(999)
            }
            
            let button = UIButton(type: .system)
            button.accessibilityLabel = title
            button.addTarget(self, action: infoAction, for: .touchUpInside)
            contentView.addSubview(button)
            button.snp.makeConstraints { make in
                make.center.equalTo(infoView)
                make.size.equalTo(36)
            }
            infoButton = button
        } else {
            infoButton = nil
        }
        stackView.addArrangedSubview(contentLabel)
        
        let activityIndicator: ActivityIndicatorView?
        if showsActivityIndicator {
            let indicator = ActivityIndicatorView()
            indicator.style = .custom(diameter: 10, lineWidth: 2)
            indicator.tintColor = R.color.text_tertiary()
            indicator.isHidden = true
            stackView.addSubview(indicator)
            indicator.snp.makeConstraints { make in
                make.centerY.trailing.equalTo(contentLabel)
                make.size.equalTo(16)
            }
            activityIndicator = indicator
        } else {
            activityIndicator = nil
        }
        return DescriptionRow(
            stackView: stackView,
            titleLabel: titleLabel,
            contentLabel: contentLabel,
            infoButton: infoButton,
            activityIndicator: activityIndicator,
        )
    }
    
    func selectReduction(percentage: Decimal, amount: Decimal) {
        inputPercentage(percentage)
    }
    
    func inputAmount(_ amount: Decimal) {
        input = Input(mode: .byAmount, value: amount)
        updateValueViews(updatingValueTextField: true)
        updateDescriptions(refreshValidation: true)
    }
    
    func updateDescriptions(refreshValidation: Bool) {
        
    }
    
    func refreshInput(refreshValidation: Bool) {
        updateValueViews(
            updatingValueTextField: !valueTextField.isFirstResponder || input.mode != amountDisplay
        )
        updateDescriptions(refreshValidation: refreshValidation)
    }
    
    func inputPercentage(_ percentage: Decimal) {
        let percentage = min(1, max(0, percentage))
        input = Input(mode: .byPercentage, value: percentage)
        updateValueViews(updatingValueTextField: true)
        updateDescriptions(refreshValidation: true)
    }
    
    func showError(description: String?, color: UIColor) {
        errorDescriptionButton.isEnabled = false
        errorDescriptionButton.configuration?.attributedTitle = description.map { description in
            var title = AttributedString(description)
            title.font = .preferredFont(forTextStyle: .caption1)
            title.foregroundColor = color
            return title
        }
        errorDescriptionButton.alpha = description == nil ? 0 : 1
    }
    
    func updateInputColor(_ color: UIColor) {
        valueTextField.textColor = color
        let signColor = valueTextField.hasText ? color : valuePlaceholderColor
        leftSignLabel.textColor = signColor
        rightSignLabel.textColor = signColor
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
                self.updateSubtitle()
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
    }
    
    @objc private func selectMarking(_ sender: UIButton) {
        guard let index = markingButtons.firstIndex(of: sender) else {
            return
        }
        selectReduction(
            percentage: markingPercentages[index],
            amount: markingAmounts[index],
        )
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
    
    struct DescriptionRow {
        
        let stackView: UIStackView
        let titleLabel: UILabel
        let contentLabel: UILabel
        let infoButton: UIButton?
        let activityIndicator: ActivityIndicatorView?
        
        var isHidden: Bool {
            get {
                stackView.isHidden
            }
            nonmutating set {
                stackView.isHidden = newValue
                infoButton?.isHidden = newValue
            }
        }
        
    }
    
    enum AmountDisplay: Int {
        case byAmount       = 0
        case byPercentage   = 1
    }
    
    struct Input {
        
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
            inputAmount(value)
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
    
}
