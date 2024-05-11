import UIKit
import Alamofire
import MixinServices

class InputAmountViewController: UIViewController {
    
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var calculatedValueLabel: UILabel!
    @IBOutlet weak var insufficientBalanceLabel: UILabel!
    @IBOutlet weak var tokenIconView: BadgeIconView!
    @IBOutlet weak var tokenNameLabel: UILabel!
    @IBOutlet weak var tokenBalanceLabel: UILabel!
    @IBOutlet weak var inputMaxValueButton: UIButton!
    @IBOutlet weak var decimalSeparatorButton: HighlightableButton!
    @IBOutlet weak var reviewButton: RoundedButton!
    
    var token: Web3TransferableToken {
        fatalError("Must override")
    }
    
    private(set) var amountIntent: AmountIntent
    private(set) var tokenAmount: Decimal = 0
    private(set) var fiatMoneyAmount: Decimal = 0
    
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
        inputMaxValueButton.setTitle(R.string.localizable.max().uppercased(), for: .normal)
        decimalSeparatorButton.setTitle(Locale.current.decimalSeparator ?? ".", for: .normal)
        reloadViews(inputAmount: accumulator.decimal)
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
    
    @IBAction func inputMaxValue(_ sender: Any) {
        var accumulator = DecimalAccumulator(intent: .byToken)
        accumulator.decimal = token.decimalBalance
        self.amountIntent = .byToken
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
        
        if tokenAmount > token.decimalBalance {
            insufficientBalanceLabel.alpha = 1
            reviewButton.isEnabled = false
        } else {
            insufficientBalanceLabel.alpha = 0
            reviewButton.isEnabled = tokenAmount > 0
        }
    }
    
}
