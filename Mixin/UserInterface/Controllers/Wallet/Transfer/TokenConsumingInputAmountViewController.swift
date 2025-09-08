import UIKit
import MixinServices

class TokenConsumingInputAmountViewController: InputAmountViewController {
    
    @IBOutlet weak var tokenIconView: BadgeIconView!
    @IBOutlet weak var tokenNameLabel: UILabel!
    @IBOutlet weak var tokenBalanceLabel: UILabel!
    
    let token: ValuableToken & OnChainToken
    
    var addTokenAttributes: AttributeContainer {
        var container = AttributeContainer()
        container.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14, weight: .medium)
        )
        container.foregroundColor = R.color.theme()
        return container
    }
    
    private let tokenPrecision: Int16
    
    private(set) var amountIntent: AmountIntent
    private(set) var tokenAmount: Decimal = 0
    private(set) var fiatMoneyAmount: Decimal = 0
    private(set) var inputAmountRequirement: BalanceRequirement // Changes when input amout changes
    
    private lazy var tokenAmountRoundingHandler = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: tokenPrecision,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    
    init(token: ValuableToken & OnChainToken, precision: Int16) {
        let accumulator = DecimalAccumulator(precision: precision)
        self.token = token
        self.tokenPrecision = precision
        self.amountIntent = .byToken
        self.inputAmountRequirement = BalanceRequirement(
            token: token,
            amount: accumulator.decimal
        )
        super.init(accumulator: accumulator)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let balanceReportingView = R.nib.balanceReportingView(withOwner: self)!
        accessoryStackView.addArrangedSubview(balanceReportingView)
        balanceReportingView.snp.makeConstraints { make in
            make.height.equalTo(72)
            make.width.equalTo(view.safeAreaLayoutGuide).offset(-40)
        }
        
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
        let multipliersStackView = UIStackView(arrangedSubviews: multiplierButtons)
        multipliersStackView.axis = .horizontal
        multipliersStackView.alignment = .fill
        multipliersStackView.distribution = .equalSpacing
        accessoryStackView.addArrangedSubview(multipliersStackView)
        multipliersStackView.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.width.equalTo(view).offset(-56)
        }
        for button in multiplierButtons {
            button.snp.makeConstraints { make in
                make.width.equalTo(view.snp.width)
                    .multipliedBy(0.24)
                    .priority(.high)
            }
        }
    }
    
    override func toggleAmountIntent(_ sender: Any) {
        var accumulator: DecimalAccumulator
        switch amountIntent {
        case .byToken:
            amountIntent = .byFiatMoney
            accumulator = .fiatMoney()
        case .byFiatMoney:
            amountIntent = .byToken
            accumulator = DecimalAccumulator(precision: tokenPrecision)
        }
        accumulator.decimal = self.accumulator.decimal
        self.accumulator = accumulator
    }
    
    override func reloadViews(inputAmount: Decimal) {
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
            tokenAmount = NSDecimalNumber(decimal: inputAmount / price)
                .rounding(accordingToBehavior: tokenAmountRoundingHandler)
                .decimalValue
            fiatMoneyAmount = inputAmount
            calculatedValueLabel.text = CurrencyFormatter.localizedString(from: tokenAmount, format: .precision, sign: .never, symbol: .custom(token.symbol))
            inputAmountString.append(" " + Currency.current.code)
        }
        
        amountLabel.text = inputAmountString
        
        inputAmountRequirement = BalanceRequirement(token: token, amount: tokenAmount)
        reloadViewsWithBalanceRequirements()
    }
    
    override func replaceAmount(_ amount: Decimal) {
        var accumulator = DecimalAccumulator(precision: tokenPrecision)
        accumulator.decimal = amount
        self.amountIntent = .byToken
        self.accumulator = accumulator
    }
    
    @objc func inputMultipliedAmount(_ sender: UIButton) {
        let multiplier = self.multiplier(tag: sender.tag)
        replaceAmount(token.decimalBalance * multiplier)
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
    
    func reloadViewsWithBalanceRequirements() {
        if inputAmountRequirement.isSufficient {
            insufficientBalanceLabel.text = nil
            reviewButton.isEnabled = tokenAmount > 0
        } else {
            insufficientBalanceLabel.text = R.string.localizable.insufficient_balance()
            reviewButton.isEnabled = false
        }
    }
    
}
