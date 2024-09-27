import UIKit
import MixinServices

class AddMarketAlertViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var iconImageView: PlainTokenIconView!
    @IBOutlet weak var tokenNameLabel: UILabel!
    @IBOutlet weak var tokenPriceLabel: UILabel!
    @IBOutlet weak var alertTypeTitleLabel: UILabel!
    @IBOutlet weak var alertTypeLabel: UILabel!
    @IBOutlet weak var alertTypeButton: UIButton!
    @IBOutlet weak var inputTitleLabel: UILabel!
    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var localCurrencyValueLabel: UILabel!
    @IBOutlet weak var invalidPriceLabel: UILabel!
    @IBOutlet weak var presetPercentageStackView: UIStackView!
    @IBOutlet weak var alertFrequencyTitleLabel: UILabel!
    @IBOutlet weak var alertFrequencyLabel: UILabel!
    @IBOutlet weak var alertFrequencyButton: UIButton!
    @IBOutlet weak var addAlertButton: RoundedButton!
    
    @IBOutlet weak var addAlertButtonBottomConstraint: NSLayoutConstraint!
    
    let market: Market
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
            switch alertType {
            case .priceReached, .priceIncreased, .priceDecreased:
                inputTitleLabel.text = R.string.localizable.price_in_currency("USD")
            case .percentageIncreased, .percentageDecreased:
                inputTitleLabel.text = R.string.localizable.value()
            }
        }
    }
    var alertFrequency: MarketAlert.AlertFrequency = .once
    
    var decimalInputValue: Decimal? {
        Decimal(string: inputTextField.text ?? "", locale: .current)
    }
    
    private let changePercentages: [Decimal] = [
        -0.2, -0.1, -0.05, 0.05, 0.1, 0.2
    ]
    
    init(market: Market) {
        self.market = market
        let nib = R.nib.addMarketAlertView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    static func contained(market: Market) -> ContainerViewController {
        let alert = AddMarketAlertViewController(market: market)
        let container = ContainerViewController.instance(viewController: alert, title: R.string.localizable.add_alert())
        container.loadViewIfNeeded()
        container.view.backgroundColor = R.color.background_secondary()
        container.navigationBar.backgroundColor = R.color.background_secondary()
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        iconImageView.setIcon(market: market)
        tokenNameLabel.text = market.name
        tokenPriceLabel.text = R.string.localizable.current_price(market.localizedUSDPrice)
        alertTypeTitleLabel.text = R.string.localizable.alert_type()
        alertTypeLabel.text = alertType.description
        reloadAlertTypeMenu()
        alertTypeButton.showsMenuAsPrimaryAction = true
        alertFrequencyTitleLabel.text = R.string.localizable.alert_frequency()
        alertFrequencyLabel.text = alertFrequency.description
        reloadAlertFrequencyMenu()
        alertFrequencyButton.showsMenuAsPrimaryAction = true
        inputTextField.text = formatter.string(from: market.decimalPrice as NSDecimalNumber)
        inputTextField.becomeFirstResponder()
        validateInput()
        invalidPriceLabel.text = R.string.localizable.price_cannot_be_current()
        for (i, percentage) in changePercentages.enumerated() {
            let button = PresetPercentageButton(type: .system)
            let title = NumberFormatter.percentage.string(decimal: percentage)
            button.setTitle(title, for: .normal)
            button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 12, weight: .medium), adjustForContentSize: true)
            button.setTitleColor(R.color.text(), for: .normal)
            button.tag = i
            button.layer.masksToBounds = true
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            presetPercentageStackView.addArrangedSubview(button)
            button.addTarget(self, action: #selector(loadPresetPercentage(_:)), for: .touchUpInside)
        }
        addAlertButton.setTitle(R.string.localizable.add_alert(), for: .normal)
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let keyboardHeight = view.bounds.height - keyboardFrame.origin.y
        addAlertButtonBottomConstraint.constant = keyboardHeight + 12
        view.layoutIfNeeded()
    }
    
    @IBAction func detectInput(_ sender: Any) {
        validateInput()
    }
    
    @IBAction func addAlert(_ sender: Any) {
        formatter.locale = .enUSPOSIX
        defer {
            formatter.locale = .current
        }
        guard let decimalInputValue, let value = formatter.string(decimal: decimalInputValue) else {
            return
        }
        addAlertButton.isBusy = true
        RouteAPI.addMarketAlert(
            coinID: market.coinID,
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
                self?.navigationController?.popViewController(animated: true)
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @objc private func loadPresetPercentage(_ sender: UIButton) {
        let percentage = changePercentages[sender.tag]
        let value = switch alertType {
        case .priceReached, .priceIncreased, .priceDecreased:
            market.decimalPrice * (1 + percentage)
        case .percentageIncreased, .percentageDecreased:
            percentage * 100
        }
        inputTextField.text = formatter.string(from: value as NSDecimalNumber)
        validateInput()
    }
    
    private func reloadAlertTypeMenu() {
        alertTypeButton.menu = UIMenu(children: MarketAlert.AlertType.allCases.map { type in
            UIAction(title: type.description, state: type == alertType ? .on : .off) { [weak self] _ in
                self?.swith(to: type)
            }
        })
    }
    
    private func swith(to type: MarketAlert.AlertType) {
        self.alertType = type
        alertTypeLabel.text = type.description
        reloadAlertTypeMenu()
        switch alertType {
        case .priceReached, .priceIncreased, .priceDecreased, .percentageIncreased:
            for button in presetPercentageStackView.arrangedSubviews {
                button.isHidden = false
            }
        case .percentageDecreased:
            let numberOfNegativeValues = changePercentages.firstIndex(where: { $0 >= 0 }) ?? 0
            for button in presetPercentageStackView.arrangedSubviews.prefix(numberOfNegativeValues) {
                button.isHidden = true
            }
        }
        validateInput()
    }
    
    private func reloadAlertFrequencyMenu() {
        alertFrequencyButton.menu = UIMenu(children: MarketAlert.AlertFrequency.allCases.map { frequency in
            UIAction(title: frequency.description, state: frequency == alertFrequency ? .on : .off) { [weak self] _ in
                self?.swith(to: frequency)
            }
        })
    }
    
    private func swith(to frequency: MarketAlert.AlertFrequency) {
        self.alertFrequency = frequency
        alertFrequencyLabel.text = alertFrequency.description
        reloadAlertFrequencyMenu()
    }
    
    private func validateInput() {
        guard let value = decimalInputValue else {
            invalidPriceLabel.isHidden = true
            addAlertButton.isEnabled = false
            return
        }
        let isValid = switch alertType {
        case .priceReached:
            value != market.decimalPrice && value >= market.decimalPrice / 1000 && value <= market.decimalPrice * 1000
        case .priceIncreased:
            value > market.decimalPrice && value <= market.decimalPrice * 1000
        case .priceDecreased:
            value < market.decimalPrice && value >= market.decimalPrice / 1000
        case .percentageIncreased, .percentageDecreased:
            value >= 0.01 && value <= 10
        }
        inputTextField.textColor = isValid ? R.color.text() : R.color.error_red()
        invalidPriceLabel.isHidden = isValid
        addAlertButton.isEnabled = isValid
    }
    
}

extension AddMarketAlertViewController {
    
    private final class PresetPercentageButton: OutlineButton {
        
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = bounds.height / 2
        }
        
    }
    
}
