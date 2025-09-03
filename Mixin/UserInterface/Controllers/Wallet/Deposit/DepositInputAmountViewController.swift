import UIKit
import MixinServices

final class DepositInputAmountViewController: InputAmountViewController {
    
    let token: ValuableToken & OnChainToken
    
    private let tokenPrecision: Int
    
    private(set) var amountIntent: AmountIntent
    private(set) var tokenAmount: Decimal = 0
    private(set) var fiatMoneyAmount: Decimal = 0
    
    private lazy var tokenAmountRoundingHandler = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: Int16(tokenPrecision),
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    
    init(token: ValuableToken & OnChainToken, precision: Int) {
        let accumulator = DecimalAccumulator(precision: precision)
        self.token = token
        self.tokenPrecision = precision
        self.amountIntent = .byToken
        super.init(accumulator: accumulator)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.enter_amount()
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_title_close(),
            target: self,
            action: #selector(close(_:))
        )
    }
    
    @objc private func close(_ sender: Any) {
        navigationController?.presentingViewController?.dismiss(animated: true)
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
    }
    
    override func review(_ sender: Any) {
        
    }
    
}
