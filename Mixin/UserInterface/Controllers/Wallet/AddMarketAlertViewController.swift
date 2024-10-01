import UIKit
import MixinServices

class AddMarketAlertViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var iconImageView: PlainTokenIconView!
    @IBOutlet weak var tokenNameLabel: UILabel!
    @IBOutlet weak var tokenPriceLabel: UILabel!
    @IBOutlet weak var alertTypeTitleLabel: UILabel!
    @IBOutlet weak var alertTypeLabel: UILabel!
    @IBOutlet weak var alertTypeButton: UIButton!
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
    @IBOutlet weak var alertFrequencyButton: UIButton!
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
        return formatter
    }()
    
    var alertType: MarketAlert.AlertType = .priceReached {
        didSet {
            guard isViewLoaded else {
                return
            }
            reloadInputTitle()
        }
    }
    
    var alertFrequency: MarketAlert.AlertFrequency = .once
    
    var decimalInputValue: Decimal? {
        Decimal(string: inputTextField.text ?? "", locale: .current)
    }
    
    var initialInput: String? {
        formatter.string(from: coin.decimalPrice as NSDecimalNumber)
    }
    
    private let changePercentages: [Decimal] = [
        -0.2, -0.1, -0.05, 0.05, 0.1, 0.2
    ]
    
    init(coin: MarketAlertCoin) {
        self.coin = coin
        let nib = R.nib.addMarketAlertView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    static func contained(coin: MarketAlertCoin) -> ContainerViewController {
        let alert = AddMarketAlertViewController(coin: coin)
        let container = ContainerViewController.instance(viewController: alert, title: R.string.localizable.add_alert())
        container.loadViewIfNeeded()
        container.view.backgroundColor = R.color.background_secondary()
        container.navigationBar.backgroundColor = R.color.background_secondary()
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        iconImageView.setIcon(coin: coin)
        tokenNameLabel.text = coin.name
        tokenPriceLabel.text = R.string.localizable.current_price(coin.localizedUSDPrice)
        alertTypeTitleLabel.text = R.string.localizable.alert_type()
        reloadAlertTypeMenu()
        alertTypeButton.showsMenuAsPrimaryAction = true
        alertFrequencyTitleLabel.text = R.string.localizable.alert_frequency()
        alertFrequencyLabel.text = alertFrequency.description
        reloadAlertFrequencyMenu()
        alertFrequencyButton.showsMenuAsPrimaryAction = true
        reloadInputTitle()
        inputTextField.placeholder = zeroWith2Fractions
        inputTextField.text = initialInput
        inputTextField.becomeFirstResponder()
        for (i, percentage) in changePercentages.enumerated() {
            let button = PresetPercentageButton(type: .system)
            let title = NumberFormatter.percentage.string(decimal: percentage)
            button.setTitle(title, for: .normal)
            button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 12, weight: .medium), adjustForContentSize: true)
            button.setTitleColor(R.color.text(), for: .normal)
            button.tag = i
            button.layer.masksToBounds = true
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 9, bottom: 8, right: 9)
            presetPercentageStackView.addArrangedSubview(button)
            button.addTarget(self, action: #selector(loadPresetPercentage(_:)), for: .touchUpInside)
        }
        switchToType(alertType)
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
        inputTextField.becomeFirstResponder()
    }
    
    @IBAction func detectInput(_ sender: Any) {
        validateInput()
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
            if value < 0.001 || value > 1000 {
                R.string.localizable.price_increase_invalid("10%", "1000%")
            } else {
                nil
            }
        case .percentageDecreased:
            if value < 0.001 || value > 1000 {
                R.string.localizable.price_decrease_invalid("10%", "1000%")
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
        controllers.removeAll { controller in
            if let container = controller as? ContainerViewController {
                if container.viewController is AllMarketAlertsViewController {
                    goesToAllMarketAlerts = true
                }
                return container.viewController is MarketAlertViewController
                || container.viewController is AddMarketAlertViewController
            } else {
                return false
            }
        }
        let alerts = if goesToAllMarketAlerts {
            AllMarketAlertsViewController.contained()
        } else {
            CoinMarketAlertsViewController.contained(coin: coin)
        }
        controllers.append(alerts)
        navigationController.setViewControllers(controllers, animated: true)
    }
    
}

extension AddMarketAlertViewController {
    
    private final class PresetPercentageButton: OutlineButton {
        
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = bounds.height / 2
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
        let percentage = changePercentages[sender.tag]
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
    
    private func reloadAlertTypeMenu() {
        alertTypeButton.menu = UIMenu(children: MarketAlert.AlertType.allCases.map { type in
            UIAction(title: type.description, state: type == alertType ? .on : .off) { [weak self] _ in
                self?.switchToType(type)
            }
        })
    }
    
    private func switchToType(_ type: MarketAlert.AlertType) {
        self.alertType = type
        alertTypeLabel.text = type.description
        reloadAlertTypeMenu()
        inputTextField.text = nil
        let center = changePercentages.firstIndex(where: { $0 > 0 }) ?? 0
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
        alertFrequencyLabel.text = alertFrequency.description
        reloadAlertFrequencyMenu()
    }
    
    private func reloadAlertFrequencyMenu() {
        alertFrequencyButton.menu = UIMenu(children: MarketAlert.AlertFrequency.allCases.map { frequency in
            UIAction(title: frequency.description, state: frequency == alertFrequency ? .on : .off) { [weak self] _ in
                self?.switchToFrequencey(frequency)
            }
        })
    }
    
}
