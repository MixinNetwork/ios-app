import UIKit
import MixinServices

class PerpsMarginInputViewController: UIViewController {
    
    @IBOutlet weak var marginView: UIView!
    @IBOutlet weak var marginContentStackView: UIStackView!
    @IBOutlet weak var marginTitleLabel: UILabel!
    @IBOutlet weak var marginNetworkLabel: UILabel!
    @IBOutlet weak var marginTokenSelectorStackView: UIStackView!
    @IBOutlet weak var marginAmountTextField: UITextField!
    @IBOutlet weak var marginTokenIconView: BadgeIconView!
    @IBOutlet weak var marginTokenSymbolLabel: UILabel!
    @IBOutlet weak var marginTokenFooterStackView: UIStackView!
    @IBOutlet weak var marginTokenBalanceButton: UIButton!
    @IBOutlet weak var marginTokenDepositButton: UIButton!
    @IBOutlet weak var marginTokenNameLabel: UILabel!
    @IBOutlet weak var marginLoadingView: ActivityIndicatorView!
    
    var marginAmount: Decimal = 0
    
    var marginTokens: [MixinTokenItem] = []
    var marginToken: MixinTokenItem? {
        didSet {
            guard let token = marginToken else {
                marginTokenDepositButton.isHidden = true
                marginAmountTextField.inputAccessoryView = nil
                return
            }
            marginNetworkLabel.text = token.depositNetworkName
            marginTokenIconView.setIcon(token: token)
            marginTokenSymbolLabel.text = token.symbol
            marginTokenBalanceButton.configuration?.attributedTitle = AttributedString(
                CurrencyFormatter.localizedString(
                    from: token.decimalBalance,
                    format: .precision,
                    sign: .never
                ),
                attributes: {
                    var attributes = AttributeContainer()
                    attributes.font = .preferredFont(forTextStyle: .caption1)
                    return attributes
                }()
            )
            marginTokenDepositButton.isHidden = token.decimalBalance > 0
            marginTokenNameLabel.text = token.name
            if marginAmountTextField.inputAccessoryView == nil {
                let accessoryView = TradeInputAccessoryView(
                    frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44)
                )
                accessoryView.items = [
                    .init(title: "25%") { [weak self] in
                        self?.inputAmount(withBalanceMultipliedBy: 0.25)
                        reporter.report(event: .tradePerpsAmountInputPercent, tags: ["percent": "25%"])
                    },
                    .init(title: "50%") { [weak self] in
                        self?.inputAmount(withBalanceMultipliedBy: 0.5)
                        reporter.report(event: .tradePerpsAmountInputPercent, tags: ["percent": "50%"])
                    },
                    .init(title: R.string.localizable.max()) { [weak self] in
                        self?.inputAmount(withBalanceMultipliedBy: 1)
                        reporter.report(event: .tradePerpsAmountInputPercent, tags: ["percent": "max"])
                    },
                ]
                accessoryView.onDone = { [weak textField=marginAmountTextField] in
                    textField?.resignFirstResponder()
                }
                marginAmountTextField.inputAccessoryView = accessoryView
            }
        }
    }
    
    private let marginAmountPrecisionValidator = MarginAmountPrecisionValidator()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        marginView.layer.cornerRadius = 8
        marginView.layer.masksToBounds = true
        marginContentStackView.setCustomSpacing(0, after: marginTokenSelectorStackView)
        marginTitleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        marginTitleLabel.text = R.string.localizable.amount()
        marginNetworkLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        marginAmountTextField.delegate = marginAmountPrecisionValidator
        marginTokenFooterStackView.setCustomSpacing(0, after: marginTokenBalanceButton)
        marginTokenBalanceButton.titleLabel?.adjustsFontForContentSizeCategory = true
        marginTokenDepositButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFont.preferredFont(forTextStyle: .caption1)
            return AttributedString(R.string.localizable.add(), attributes: attributes)
        }()
        marginTokenDepositButton.titleLabel?.adjustsFontForContentSizeCategory = true
        marginLoadingView.startAnimating()
        
        reloadMarginTokens()
    }
    
    @IBAction func editMarginAmount(_ textField: UITextField) {
        let amount: Decimal = if let text = textField.text {
            Decimal(string: text, locale: .current) ?? 0
        } else {
            0
        }
        self.marginAmount = amount
    }
    
    @IBAction func pickMarginToken(_ sender: Any) {
        let selector = SimpleTokenSelectorViewController(
            tokens: marginTokens,
            selectedAssetID: marginToken?.assetID
        )
        selector.onSelected = { token in
            self.marginToken = token as? MixinTokenItem
            self.dismiss(animated: true)
        }
        present(selector, animated: true, completion: nil)
    }
    
    @IBAction func inputTokenBalance(_ sender: Any) {
        inputAmount(withBalanceMultipliedBy: 1)
        reporter.report(event: .tradePerpsAmountInputBalance)
    }
    
    @IBAction func depositMarginToken(_ sender: Any) {
        guard let marginToken else {
            return
        }
        let selector = AddTokenMethodSelectorViewController(token: marginToken)
        selector.delegate = self
        present(selector, animated: true)
    }
    
    func inputAmount(withBalanceMultipliedBy balanceMultiplier: Decimal) {
        guard let token = marginToken else {
            return
        }
        marginAmount = token.decimalBalance * balanceMultiplier
        marginAmountTextField.text = CurrencyFormatter.localizedString(
            from: marginAmount,
            format: .precision,
            sign: .never,
        )
    }
    
    private func reloadMarginTokens() {
        RouteAPI.acceptedPerpsOrderAssets(queue: .global()) { [weak self] result in
            switch result {
            case .success(let assetIDs):
                let orders = assetIDs.enumerated()
                    .reduce(into: [:]) { results, enumerated in
                        results[enumerated.element] = enumerated.offset
                    }
                let comparator = MarginTokenComparator(orders: orders)
                let tokens = TokenDAO.shared.tokenItems(with: assetIDs)
                    .sorted(using: comparator)
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.marginTokens = tokens
                    self.marginToken = tokens.first
                    if !tokens.isEmpty {
                        self.marginTokenSelectorStackView.alpha = 1
                        self.marginTokenFooterStackView.alpha = 1
                        self.marginLoadingView.stopAnimating()
                    }
                }
                let missingAssetIDs = Set(assetIDs).subtracting(tokens.map(\.assetID))
                if !missingAssetIDs.isEmpty {
                    let chains = ChainDAO.shared.allChains()
                    self?.requestMissingMarginTokens(
                        assetIDs: missingAssetIDs,
                        chains: chains,
                        existedTokens: tokens,
                        comparator: comparator,
                    )
                }
            case .failure(let error):
                Logger.general.debug(category: "OpenPerpsPosition", message: "Margin Tokens: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.reloadMarginTokens()
                }
            }
        }
    }
    
    private func requestMissingMarginTokens(
        assetIDs: Set<String>,
        chains: [String: Chain],
        existedTokens: [MixinTokenItem],
        comparator: MarginTokenComparator,
    ) {
        SafeAPI.assets(ids: assetIDs, queue: .global()) { [weak self] result in
            switch result {
            case .success(let tokens):
                var items = existedTokens + tokens.map { token in
                    MixinTokenItem(
                        token: token,
                        balance: "0",
                        isHidden: false,
                        chain: chains[token.chainID]
                    )
                }
                items.sort(using: comparator)
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.marginTokens = items
                    if self.marginToken == nil {
                        self.marginToken = items.first
                    }
                    self.marginTokenSelectorStackView.alpha = 1
                    self.marginTokenFooterStackView.alpha = 1
                    self.marginLoadingView.stopAnimating()
                }
            case .failure(let error):
                Logger.general.debug(category: "OpenPerpsPosition", message: "Missing Tokens: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.requestMissingMarginTokens(
                        assetIDs: assetIDs,
                        chains: chains,
                        existedTokens: existedTokens,
                        comparator: comparator
                    )
                }
            }
        }
    }
    
}

extension PerpsMarginInputViewController: AddTokenMethodSelectorViewController.Delegate {
    
    func addTokenMethodSelectorViewController(
        _ viewController: AddTokenMethodSelectorViewController,
        didPickMethod method: AddTokenMethodSelectorViewController.Method
    ) {
        guard let token = marginToken, let navigationController else {
            return
        }
        switch method {
        case .trade:
            var viewControllers = navigationController.viewControllers
            let index = viewControllers.firstIndex { viewController in
                viewController is TradeViewController
                || viewController is PerpetualMarketViewController
            }
            if let index {
                let count = viewControllers.count - index
                viewControllers.removeLast(count)
            }
            UserOperationAnalytics.tradeSource = .perpsMarginInput
            let trade = TradeViewController(
                wallet: .privacy,
                trading: .simpleSpot,
                sendAssetID: nil,
                receiveAssetID: token.assetID,
                referral: nil
            )
            if let trade {
                viewControllers.append(trade)
                navigationController.setViewControllers(viewControllers, animated: true)
            }
        case .deposit:
            let deposit = DepositViewController(token: token, switchingBetweenNetworks: false)
            navigationController.pushViewController(replacingCurrent: deposit, animated: true)
        }
    }
    
}

extension PerpsMarginInputViewController {
    
    final class AmountValidator {
        
        enum Result {
            case valid
            case invalid(reason: String)
        }
        
        private let minAmount: Decimal
        private let maxAmount: Decimal?
        
        init(market: PerpetualMarket) {
            minAmount = Decimal(string: market.minAmount, locale: .enUSPOSIX) ?? 1
            maxAmount = Decimal(string: market.maxAmount, locale: .enUSPOSIX)
        }
        
        func validate(amount: Decimal, symbol: String) -> Result {
            if amount < minAmount {
                let min = CurrencyFormatter.localizedString(from: minAmount, format: .precision, sign: .never)
                let reason = R.string.localizable.single_transaction_should_be_greater_than(min, symbol)
                return .invalid(reason: reason)
            } else if let maxAmount, amount > maxAmount {
                let max = CurrencyFormatter.localizedString(from: maxAmount, format: .precision, sign: .never)
                let reason = R.string.localizable.single_transaction_should_be_less_than(max, symbol)
                return .invalid(reason: reason)
            } else {
                return .valid
            }
        }
        
    }
    
    private final class MarginAmountPrecisionValidator: NSObject, UITextFieldDelegate {
        
        var precision = MixinToken.internalPrecision
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let oldText = textField.text ?? ""
            let newText = (oldText as NSString).replacingCharacters(in: range, with: string)
            if newText.isEmpty || newText.count < oldText.count {
                return true
            } else if let value = Decimal(string: newText, locale: .current) {
                return value.numberOfSignificantFractionalDigits <= precision
            } else {
                return false
            }
        }
        
    }
    
    private struct MarginTokenComparator: SortComparator {
        
        var order: SortOrder = .forward
        
        private let orders: [String: Int]
        
        init(orders: [String: Int]) {
            self.orders = orders
        }
        
        func compare(_ lhs: MixinTokenItem, _ rhs: MixinTokenItem) -> ComparisonResult {
            let result = withUnsafePointer(to: lhs.decimalBalance) { l in
                withUnsafePointer(to: rhs.decimalBalance) { r in
                    NSDecimalCompare(l, r)
                }
            }
            let forwardResult: ComparisonResult
            switch result {
            case .orderedAscending:
                forwardResult = .orderedDescending
            case .orderedDescending:
                forwardResult = .orderedAscending
            case .orderedSame:
                let l = orders[lhs.assetID] ?? -1
                let r = orders[rhs.assetID] ?? -1
                forwardResult = if l > r {
                    .orderedDescending
                } else if l == r {
                    .orderedSame
                } else {
                    .orderedAscending
                }
            }
            return switch order {
            case .forward:
                 forwardResult
            case .reverse:
                switch forwardResult {
                case .orderedAscending:
                        .orderedDescending
                case .orderedDescending:
                        .orderedAscending
                case .orderedSame:
                        .orderedSame
                }
            }
        }
        
    }
    
}
