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
        scale: MixinToken.internalPrecision,
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
        switch link.chain {
        case .native(let context):
            guard tokenAmount != 0, let limitation = context.limitation else {
                fallthrough
            }
            switch limitation.check(value: tokenAmount) {
            case .lessThanMinimum(let minimum):
                let min = CurrencyFormatter.localizedString(
                    from: minimum,
                    format: .precision,
                    sign: .never,
                )
                insufficientBalanceLabel.text = R.string.localizable.single_transaction_should_be_greater_than(min, context.token.symbol)
                reviewButton.isEnabled = false
            case .greaterThanMaximum(let maximum):
                let max = CurrencyFormatter.localizedString(
                    from: maximum,
                    format: .precision,
                    sign: .never,
                )
                insufficientBalanceLabel.text = R.string.localizable.single_transaction_should_be_less_than(max, context.token.symbol)
                reviewButton.isEnabled = false
            case .within:
                insufficientBalanceLabel.text = nil
                reviewButton.isEnabled = true
            }
        case .mixin:
            insufficientBalanceLabel.text = nil
            reviewButton.isEnabled = tokenAmount != 0
        }
    }
    
    override func review(_ sender: Any) {
        switch token.chainID {
        case ChainID.lightning:
            insufficientBalanceLabel.text = nil
            reviewButton.isBusy = true
            let amount = self.tokenAmount
            let amountString = TokenAmountFormatter.string(from: amount)
            Task { [token] in
                do {
                    let entries = try await SafeAPI.depositEntries(
                        assetID: token.assetID,
                        chainID: token.chainID,
                        amount: amountString
                    )
                    let entry = entries.first(where: \.isPrimary) ?? entries.first
                    guard let entry else {
                        throw MixinAPIResponseError.withdrawSuspended
                    }
                    await MainActor.run {
                        self.reviewButton.isBusy = false
                        let linkWithAmount: DepositLink? = .native(
                            address: entry.destination,
                            token: token,
                            limitation: .init(minimum: entry.minimum, maximum: entry.maximum),
                            amount: amount
                        )
                        if let linkWithAmount {
                            let preview = DepositLinkPreviewViewController(link: linkWithAmount)
                            self.navigationController?.pushViewController(preview, animated: true)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.reviewButton.isBusy = false
                        self.insufficientBalanceLabel.text = error.localizedDescription
                    }
                }
            }
        default:
            switch link.chain {
            case .mixin(let context):
                let linkWithAmount: DepositLink = .mixin(
                    account: context.account,
                    specification: .init(token: token, amount: tokenAmount)
                )
                let preview = DepositLinkPreviewViewController(link: linkWithAmount)
                navigationController?.pushViewController(preview, animated: true)
            case .native(let context):
                let linkWithAmount: DepositLink? = .native(
                    address: context.address,
                    token: context.token,
                    limitation: context.limitation,
                    amount: tokenAmount
                )
                if let linkWithAmount {
                    let preview = DepositLinkPreviewViewController(link: linkWithAmount)
                    navigationController?.pushViewController(preview, animated: true)
                }
            }
        }
    }
    
}
