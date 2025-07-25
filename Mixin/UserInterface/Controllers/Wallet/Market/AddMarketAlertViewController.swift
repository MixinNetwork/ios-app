import UIKit
import MixinServices

class AddMarketAlertViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var iconImageView: PlainTokenIconView!
    @IBOutlet weak var tokenNameLabel: UILabel!
    @IBOutlet weak var tokenPriceLabel: UILabel!
    @IBOutlet weak var alertTypeTitleLabel: UILabel!
    @IBOutlet weak var alertTypeLabel: UILabel!
    @IBOutlet weak var beginInputButton: UIButton!
    @IBOutlet weak var inputTitleLabel: UILabel!
    @IBOutlet weak var inputContentStackView: UIStackView!
    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var inputTrailingLabel: UILabel!
    @IBOutlet weak var localCurrencyValueLabel: UILabel!
    @IBOutlet weak var invalidPriceLabel: UILabel!
    @IBOutlet weak var presetPercentageWrapperView: UIView!
    @IBOutlet weak var presetPercentageStackView: UIStackView!
    @IBOutlet weak var alertFrequencyTitleLabel: UILabel!
    @IBOutlet weak var alertFrequencyLabel: UILabel!
    @IBOutlet weak var addAlertButton: RoundedButton!
    
    @IBOutlet weak var addAlertButtonBottomConstraint: NSLayoutConstraint!
    
    let coin: MarketAlertCoin
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.usesGroupingSeparator = false
        formatter.positivePrefix = ""
        formatter.negativePrefix = ""
        formatter.maximumFractionDigits = 8
        return formatter
    }()
    
    var alertType: MarketAlert.AlertType {
        didSet {
            guard isViewLoaded else {
                return
            }
            reloadInputTitle()
        }
    }
    
    var alertFrequency: MarketAlert.AlertFrequency
    
    var decimalInputValue: Decimal? {
        Decimal(string: inputTextField.text ?? "", locale: .current)
    }
    
    var initialInput: String? {
        formatter.string(from: coin.decimalPrice as NSDecimalNumber)
    }
    
    private let increasePrecentageLimitation = PercentageLimitation(min: 0.0001, max: 10)
    private let decreasePrecentageLimitation = PercentageLimitation(min: 0.0001, max: 0.9999)
    private let presetChangePercentages: [Decimal] = [
        -0.2, -0.1, -0.05, 0.05, 0.1, 0.2
    ]
    
    init(
        coin: MarketAlertCoin,
        type: MarketAlert.AlertType = .priceReached,
        frequency: MarketAlert.AlertFrequency = .every
    ) {
        self.coin = coin
        self.alertType = type
        self.alertFrequency = frequency
        let nib = R.nib.addMarketAlertView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = R.string.localizable.add_alert()
        
        for (i, percentage) in presetChangePercentages.enumerated() {
            let button = ConfigurationBasedOutlineButton(type: .system)
            button.configuration = {
                var config: UIButton.Configuration = .bordered()
                config.cornerStyle = .capsule
                config.attributedTitle = AttributedString(
                    NumberFormatter.percentage.string(decimal: percentage) ?? "",
                    attributes: AttributeContainer([
                        .font: UIFontMetrics.default.scaledFont(
                            for: .systemFont(ofSize: 12, weight: .medium)
                        )
                    ])
                )
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 9, bottom: 8, trailing: 9)
                return config
            }()
            button.tag = i
            presetPercentageStackView.addArrangedSubview(button)
            button.addTarget(self, action: #selector(loadPresetPercentage(_:)), for: .touchUpInside)
        }
        
        iconImageView.setIcon(coin: coin)
        tokenNameLabel.text = coin.name
        tokenPriceLabel.text = R.string.localizable.current_price(coin.localizedUSDPrice)
        alertTypeTitleLabel.text = R.string.localizable.alert_type()
        switchToType(alertType, replacingInputWith: initialInput)
        alertFrequencyTitleLabel.text = R.string.localizable.alert_frequency()
        alertFrequencyLabel.text = alertFrequency.name
        reloadInputTitle()
        inputTextField.placeholder = zeroWith2Fractions
        inputTextField.becomeFirstResponder()
        addAlertButton.setTitle(R.string.localizable.add_alert(), for: .normal)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(beginInput(_:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let keyboardHeight = view.bounds.height - keyboardFrame.origin.y
        addAlertButtonBottomConstraint.constant = keyboardHeight + 12
        scrollView.contentInset.bottom = keyboardHeight
        view.layoutIfNeeded()
    }
    
    @IBAction func beginInput(_ sender: Any) {
        guard presentedViewController == nil else {
            return
        }
        inputTextField.becomeFirstResponder()
    }
    
    @IBAction func detectInput(_ sender: Any) {
        validateInput()
    }
    
    @IBAction func pickAlertType(_ sender: Any) {
        let selector = AlertTypeSelectorViewController(selected: alertType) { type in
            self.switchToType(type, replacingInputWith: nil)
        }
        present(selector, animated: true)
    }
    
    @IBAction func pickAlertFrequency(_ sender: Any) {
        let selector = AlertFrequencySelectorViewController(
            selection: alertFrequency,
            onSelected: self.switchToFrequencey(_:)
        )
        present(selector, animated: true)
    }
    
    @IBAction func addAlert(_ sender: Any) {
        guard let decimalInputValue else {
            return
        }
        let requestValue = switch alertType.valueType {
        case .absolute:
            decimalInputValue
        case .percentage:
            decimalInputValue / 100
        }
        formatter.locale = .enUSPOSIX
        defer {
            formatter.locale = .current
        }
        guard let value = formatter.string(decimal: requestValue) else {
            return
        }
        addAlertButton.isBusy = true
        RouteAPI.addMarketAlert(
            coinID: coin.coinID,
            type: alertType,
            frequency: alertFrequency,
            value: value
        ) { [weak self] result in
            self?.addAlertButton.isBusy = false
            switch result {
            case .success(let alert):
                DispatchQueue.global().async {
                    MarketAlertDAO.shared.save(alert: alert)
                    let job = AddBotIfNotFriendJob(userID: BotUserID.marketAlerts)
                    ConcurrentJobQueue.shared.addJob(job: job)
                }
                self?.manipulateNavigationStack()
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    func validateInput() {
        guard let value = decimalInputValue else {
            invalidPriceLabel.isHidden = true
            addAlertButton.isEnabled = false
            return
        }
        let invalidDescription: String? = switch alertType {
        case .priceReached:
            if value < coin.decimalPrice / 100 {
                R.string.localizable.price_too_less("1/100")
            } else if value > coin.decimalPrice * 100 {
                R.string.localizable.price_too_large("100")
            } else {
                nil
            }
        case .priceIncreased:
            if value <= coin.decimalPrice {
                R.string.localizable.price_must_greater_than_current()
            } else if value > coin.decimalPrice * 100 {
                R.string.localizable.price_too_large("100")
            } else {
                nil
            }
        case .priceDecreased:
            if value >= coin.decimalPrice {
                R.string.localizable.price_must_less_than_current()
            } else if value < coin.decimalPrice / 100 {
                R.string.localizable.price_too_less("1/100")
            } else {
                nil
            }
        case .percentageIncreased:
            if !increasePrecentageLimitation.contains(value: value / 100) {
                R.string.localizable.price_increase_invalid(
                    increasePrecentageLimitation.minRepresentation,
                    increasePrecentageLimitation.maxRepresentation
                )
            } else {
                nil
            }
        case .percentageDecreased:
            if !decreasePrecentageLimitation.contains(value: value / 100) {
                R.string.localizable.price_increase_invalid(
                    decreasePrecentageLimitation.minRepresentation,
                    decreasePrecentageLimitation.maxRepresentation
                )
            } else {
                nil
            }
        }
        let isValid = invalidDescription == nil
        inputTextField.textColor = isValid ? R.color.text() : R.color.error_red()
        invalidPriceLabel.text = invalidDescription
        invalidPriceLabel.isHidden = isValid
        addAlertButton.isEnabled = isValid
    }
    
    private func manipulateNavigationStack() {
        guard let navigationController else {
            return
        }
        var controllers = navigationController.viewControllers
        var goesToAllMarketAlerts = false
        controllers.removeAll { viewController in
            if viewController is AllMarketAlertsViewController {
                goesToAllMarketAlerts = true
            }
            return viewController is MarketAlertViewController
            || viewController is AddMarketAlertViewController
        }
        let alerts = if goesToAllMarketAlerts {
            AllMarketAlertsViewController()
        } else {
            CoinMarketAlertsViewController(coin: coin)
        }
        controllers.append(alerts)
        navigationController.setViewControllers(controllers, animated: true)
    }
    
}

extension AddMarketAlertViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension AddMarketAlertViewController {
    
    private struct PercentageLimitation {
        
        let min: Decimal
        let max: Decimal
        
        var minRepresentation: String {
            NumberFormatter.percentage.string(decimal: min) ?? "\(min)"
        }
        
        var maxRepresentation: String {
            NumberFormatter.percentage.string(decimal: max) ?? "\(max)"
        }
        
        func contains(value: Decimal) -> Bool {
            value >= min && value <= max
        }
        
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        beginInputButton.isHidden = true
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        addAlertButtonBottomConstraint.constant = 12
        scrollView.contentInset.bottom = 0
        view.layoutIfNeeded()
        beginInputButton.isHidden = false
    }
    
    @objc private func loadPresetPercentage(_ sender: UIButton) {
        let percentage = presetChangePercentages[sender.tag]
        let value = switch alertType.valueType {
        case .absolute:
            coin.decimalPrice * (1 + percentage)
        case .percentage:
            percentage * 100
        }
        let roundedValue = withUnsafePointer(to: value) { value in
            var roundedValue = Decimal()
            NSDecimalRound(&roundedValue, value, 2, .plain)
            return roundedValue
        }
        inputTextField.text = formatter.string(from: roundedValue as NSDecimalNumber)
        validateInput()
    }
    
    private func reloadInputTitle() {
        switch alertType.valueType {
        case .absolute:
            inputTitleLabel.text = R.string.localizable.price_in_currency("USD")
        case .percentage:
            inputTitleLabel.text = R.string.localizable.alert_value()
        }
    }
    
    private func switchToType(_ type: MarketAlert.AlertType, replacingInputWith inputText: String?) {
        self.alertType = type
        alertTypeLabel.text = type.name
        inputTextField.text = inputText
        let center = presetChangePercentages.firstIndex(where: { $0 > 0 }) ?? 0
        switch type {
        case .priceReached:
            presetPercentageWrapperView.isHidden = false
            for button in presetPercentageStackView.arrangedSubviews {
                button.isHidden = false
            }
        case .priceIncreased:
            presetPercentageWrapperView.isHidden = false
            for button in presetPercentageStackView.arrangedSubviews.prefix(center) {
                button.isHidden = true
            }
            for button in presetPercentageStackView.arrangedSubviews.suffix(center) {
                button.isHidden = false
            }
        case .priceDecreased:
            presetPercentageWrapperView.isHidden = false
            for button in presetPercentageStackView.arrangedSubviews.prefix(center) {
                button.isHidden = false
            }
            for button in presetPercentageStackView.arrangedSubviews.suffix(center) {
                button.isHidden = true
            }
        case .percentageIncreased:
            presetPercentageWrapperView.isHidden = true
        case .percentageDecreased:
            presetPercentageWrapperView.isHidden = true
        }
        switch type.valueType {
        case .absolute:
            inputContentStackView.spacing = 8
            inputTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)
            inputTrailingLabel.text = nil
            inputTrailingLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        case .percentage:
            inputContentStackView.spacing = 2
            inputTextField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            inputTrailingLabel.text = "%"
            inputTrailingLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        validateInput()
    }
    
    private func switchToFrequencey(_ frequency: MarketAlert.AlertFrequency) {
        self.alertFrequency = frequency
        alertFrequencyLabel.text = alertFrequency.name
    }
    
}
