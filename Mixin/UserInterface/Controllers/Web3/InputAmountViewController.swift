import UIKit
import Alamofire
import MixinServices

class InputAmountViewController: UIViewController {
    
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var calculatedValueLabel: UILabel!
    @IBOutlet weak var insufficientBalanceLabel: UILabel!
    @IBOutlet weak var accessoryStackView: UIStackView!
    @IBOutlet weak var multipliersStackView: UIStackView!
    @IBOutlet weak var tokenIconView: BadgeIconView!
    @IBOutlet weak var tokenNameLabel: UILabel!
    @IBOutlet weak var tokenBalanceLabel: UILabel!
    @IBOutlet weak var decimalSeparatorButton: HighlightableButton!
    @IBOutlet weak var deleteBackwardsButton: HighlightableButton!
    @IBOutlet weak var reviewButton: StyledButton!
    
    @IBOutlet var decimalButtons: [DecimalButton]!
    
    @IBOutlet weak var numberPadTopConstraint: NSLayoutConstraint!
    
    var token: TransferableToken {
        fatalError("Must override")
    }
    
    var isBalanceInsufficient: Bool {
        tokenAmount > token.decimalBalance
    }
    
    var feeAttributes: AttributeContainer {
        var container = AttributeContainer()
        container.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        container.foregroundColor = R.color.text_tertiary()
        return container
    }
    
    private(set) var amountIntent: AmountIntent
    private(set) var tokenAmount: Decimal = 0
    private(set) var fiatMoneyAmount: Decimal = 0
    
    private(set) weak var feeActivityIndicator: ActivityIndicatorView?
    private(set) weak var changeFeeButton: UIButton?
    
    private let feedback = UIImpactFeedbackGenerator(style: .light)
    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.usesGroupingSeparator = true
        formatter.positivePrefix = ""
        formatter.negativePrefix = ""
        return formatter
    }()
    
    private var accumulator: DecimalAccumulator {
        didSet {
            guard isViewLoaded else {
                return
            }
            reloadViews(inputAmount: accumulator.decimal)
        }
    }
    
    init() {
        let defaultIntent: AmountIntent = .byToken
        self.amountIntent = defaultIntent
        self.accumulator = DecimalAccumulator(intent: defaultIntent)
        let nib = R.nib.inputAmountView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        amountStackView.setCustomSpacing(2, after: amountLabel)
        amountLabel.font = .monospacedDigitSystemFont(ofSize: 64, weight: .regular)
        
        let multiplierButtons = {
            var config: UIButton.Configuration = .filled()
            config.baseForegroundColor = R.color.text()
            config.baseBackgroundColor = R.color.background_secondary()
            config.cornerStyle = .capsule
            
            let attributes = AttributeContainer([
                .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .right
                    return style
                }(),
            ])
            
            return (0...2).map { tag in
                config.attributedTitle = {
                    let multiplier = self.multiplier(tag: tag)
                    let title = switch multiplier {
                    case 1:
                        R.string.localizable.balance_max()
                    default:
                        NumberFormatter.simplePercentage.string(decimal: multiplier) ?? ""
                    }
                    return AttributedString(title, attributes: attributes)
                }()
                
                let button = UIButton(configuration: config)
                button.titleLabel?.adjustsFontForContentSizeCategory = true
                button.tag = tag
                button.addTarget(self, action: #selector(inputMultipliedAmount(_:)), for: .touchUpInside)
                return button
            }
        }()
        for button in multiplierButtons {
            multipliersStackView.addArrangedSubview(button)
            button.snp.makeConstraints { make in
                make.width.equalTo(view.snp.width)
                    .multipliedBy(0.24)
                    .priority(.high)
            }
        }
        
        decimalButtons.sort(by: { $0.value < $1.value })
        decimalSeparatorButton.setTitle(Locale.current.decimalSeparator ?? ".", for: .normal)
        reloadViews(inputAmount: accumulator.decimal)
        reviewButton.style = .filled
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let key = presses.first?.key else {
            super.pressesBegan(presses, with: event)
            return
        }
        if let value = Int(key.charactersIgnoringModifiers) {
            if value >= 0 && value < decimalButtons.count {
                let button = decimalButtons[value]
                button.isHighlighted = true
            } else {
                super.pressesBegan(presses, with: event)
            }
        } else {
            switch Key(keyCode: key.keyCode) {
            case .backspace:
                deleteBackwardsButton.isHighlighted = true
            case .decimalSeparator:
                decimalSeparatorButton.isHighlighted = true
            case .enter:
                break
            default:
                super.pressesBegan(presses, with: event)
            }
        }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for button in decimalButtons + [decimalSeparatorButton, deleteBackwardsButton] {
            button?.isHighlighted = false
        }
        guard let key = presses.first?.key else {
            super.pressesEnded(presses, with: event)
            return
        }
        if let value = UInt8(key.charactersIgnoringModifiers) {
            if value >= 0 && value < decimalButtons.count {
                accumulator.append(value: value)
            } else {
                super.pressesEnded(presses, with: event)
            }
        } else {
            switch Key(keyCode: key.keyCode) {
            case .backspace:
                accumulator.deleteBackwards()
            case .decimalSeparator:
                accumulator.appendDecimalSeparator()
            case .enter:
                review(presses)
            default:
                super.pressesEnded(presses, with: event)
            }
        }
    }
    
    @IBAction func toggleAmountIntent(_ sender: Any) {
        switch amountIntent {
        case .byToken:
            amountIntent = .byFiatMoney
        case .byFiatMoney:
            amountIntent = .byToken
        }
        var accumulator = DecimalAccumulator(intent: amountIntent)
        accumulator.decimal = self.accumulator.decimal
        self.accumulator = accumulator
    }
    
    @IBAction func inputValue(_ sender: DecimalButton) {
        accumulator.append(value: sender.value)
    }
    
    @IBAction func inputDecimalSeparator(_ sender: Any) {
        accumulator.appendDecimalSeparator()
    }
    
    @IBAction func deleteBackwards(_ sender: Any) {
        accumulator.deleteBackwards()
    }
    
    @IBAction func generateInputFeedback(_ sender: Any) {
        feedback.impactOccurred()
    }
    
    @IBAction func review(_ sender: Any) {
        
    }
    
    func multiplier(tag: Int) -> Decimal {
        switch tag {
        case 0:
            0.25
        case 1:
            0.5
        default:
            1
        }
    }
    
    func replaceAmount(_ amount: Decimal) {
        var accumulator = DecimalAccumulator(intent: .byToken)
        accumulator.decimal = amount
        self.amountIntent = .byToken
        self.accumulator = accumulator
    }
    
    @objc func inputMultipliedAmount(_ sender: UIButton) {
        let multiplier = self.multiplier(tag: sender.tag)
        replaceAmount(token.decimalBalance * multiplier)
    }
    
    func addFeeView() {
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
        self.feeActivityIndicator = activityIndicator
        
        var config: UIButton.Configuration = .plain()
        config.baseBackgroundColor = .clear
        config.imagePlacement = .trailing
        config.imagePadding = 14
        config.attributedTitle = AttributedString("0", attributes: feeAttributes)
        let button = UIButton(configuration: config)
        button.tintColor = R.color.chat_pin_count_background()
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.alpha = 0
        self.changeFeeButton = button
        
        let feeStackView = UIStackView(arrangedSubviews: [titleLabel, activityIndicator, button])
        feeStackView.axis = .horizontal
        feeStackView.alignment = .center
        
        accessoryStackView.insertArrangedSubview(feeStackView, at: 0)
        feeStackView.snp.makeConstraints { make in
            make.width.equalTo(view.snp.width).offset(-56)
        }
    }
    
}

extension InputAmountViewController {
    
    private enum Key {
        
        case backspace
        case decimalSeparator
        case enter
        
        init?(keyCode: UIKeyboardHIDUsage) {
            switch keyCode {
            case .keyboardDeleteOrBackspace:
                self = .backspace
            case .keyboardPeriod, .keyboardComma, .keypadPeriod:
                self = .decimalSeparator
            case .keyboardReturn, .keyboardReturnOrEnter, .keypadEnter:
                self = .enter
            default:
                return nil
            }
        }
        
    }
    
    private func reloadViews(inputAmount: Decimal) {
        let price = token.decimalUSDPrice * Currency.current.decimalRate
        
        formatter.alwaysShowsDecimalSeparator = accumulator.willInputFraction
        formatter.minimumFractionDigits = accumulator.fractions?.count ?? 0
        var inputAmountString = formatter.string(from: inputAmount as NSDecimalNumber) ?? "0"
        
        switch amountIntent {
        case .byToken:
            tokenAmount = inputAmount
            fiatMoneyAmount = inputAmount * price
            calculatedValueLabel.text = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencyCode)
            inputAmountString.append(" " + token.symbol)
        case .byFiatMoney:
            tokenAmount = inputAmount / price
            fiatMoneyAmount = inputAmount
            calculatedValueLabel.text = CurrencyFormatter.localizedString(from: tokenAmount, format: .precision, sign: .never, symbol: .custom(token.symbol))
            inputAmountString.append(" " + Currency.current.code)
        }
        
        amountLabel.text = inputAmountString
        
        if isBalanceInsufficient {
            insufficientBalanceLabel.alpha = 1
            reviewButton.isEnabled = false
        } else {
            insufficientBalanceLabel.alpha = 0
            reviewButton.isEnabled = tokenAmount > 0
        }
    }
    
}
