import UIKit
import MixinServices

final class DepositInputAmountViewController: InputAmountViewController {
    
    // All the precisions used here are MixinToken.internalPrecision, because whether it is an on-chain transfer or an internal transfer, the amount a user receives has at most 8 decimal places.
    
    let token: ValuableToken & OnChainToken
    
    private(set) var amountIntent: AmountIntent
    private(set) var tokenAmount: Decimal = 0
    private(set) var fiatMoneyAmount: Decimal = 0
    
    private lazy var tokenAmountRoundingHandler = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: Int16(MixinToken.internalPrecision),
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    
    private let link: DepositLink
    
    init(link: DepositLink, token: ValuableToken & OnChainToken) {
        let accumulator = DecimalAccumulator(precision: MixinToken.internalPrecision)
        self.link = link
        self.token = token
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
        insufficientBalanceLabel.text = nil
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
            accumulator = DecimalAccumulator(precision: MixinToken.internalPrecision)
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
            calculatedValueLabel.text = CurrencyFormatter.localizedString(
                from: fiatMoneyAmount,
                format: .fiatMoney,
                sign: .never,
                symbol: .currencyCode
            )
            inputAmountString.append(" " + token.symbol)
        case .byFiatMoney:
            tokenAmount = NSDecimalNumber(decimal: inputAmount / price)
                .rounding(accordingToBehavior: tokenAmountRoundingHandler)
                .decimalValue
            fiatMoneyAmount = inputAmount
            calculatedValueLabel.text = CurrencyFormatter.localizedString(
                from: tokenAmount,
                format: .precision,
                sign: .never,
                symbol: .custom(token.symbol)
            )
            inputAmountString.append(" " + Currency.current.code)
        }
        
        amountLabel.text = inputAmountString
        reviewButton.isEnabled = inputAmount != 0
    }
    
    override func review(_ sender: Any) {
        guard let link = link.replacing(token: token, amount: tokenAmount) else {
            return
        }
        let preview = DepositLinkPreviewViewController(link: link)
        navigationController?.pushViewController(preview, animated: true)
    }
    
}
