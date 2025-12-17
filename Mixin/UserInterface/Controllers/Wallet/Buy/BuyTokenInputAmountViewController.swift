import UIKit
import OrderedCollections
import PhoneNumberKit
import MixinServices

final class BuyTokenInputAmountViewController: InputAmountViewController {
    
    private typealias Token = ValuableToken & OnChainToken
    
    @IBOutlet weak var payingSelectorView: CompactComboBoxView!
    @IBOutlet weak var receivingSelectorView: CompactComboBoxView!
    
    private let wallet: Wallet
    
    private(set) var amountIntent: AmountIntent = .byFiatMoney
    private(set) var tokenAmount: Decimal = 0
    private(set) var fiatMoneyAmount: Decimal = 0
    
    private weak var minimalAmountLabel: UILabel!
    
    private var currencies: [Currency] = []
    private var selectedCurrency: Currency
    private var fiatMoneyAmountRoudingHandler: NSDecimalNumberHandler?
    
    private var tokens: [any Token] = []
    private var selectedToken: (any Token)?
    private var tokenAmountRoundingHandler: NSDecimalNumberHandler?
    
    private var minimalAmounts: [String: MinimalAmount] = [:] // Key is currencyCode + assetID
    private var minimalAmount: MinimalAmount?
    
    private var tokenPrecision: Int16 {
        if let token = selectedToken {
            if let token = token as? Web3TokenItem {
                token.precision
            } else {
                MixinToken.internalPrecision
            }
        } else {
            0
        }
    }
    
    init(wallet: Wallet) {
        self.wallet = wallet
        self.selectedCurrency = if let code = AppGroupUserDefaults.Wallet.lastBuyingCurrencyCode {
            Currency.map[code] ?? .usd
        } else {
            .usd
        }
        let accumulator = DecimalAccumulator(precision: MixinToken.internalPrecision)
        super.init(accumulator: accumulator)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = R.string.localizable.buy()
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.buy(),
            wallet: wallet
        )
        amountLabel.text = CurrencyFormatter.localizedString(
            from: 0,
            format: .precision,
            sign: .never,
            symbol: .custom(selectedCurrency.code)
        )
        insufficientBalanceLabel.isHidden = true
        
        let buyingPairView = R.nib.buyingPairView(withOwner: self) as! UIStackView
        accessoryStackView.addArrangedSubview(buyingPairView)
        buyingPairView.snp.makeConstraints { make in
            make.height.equalTo(44)
            if ScreenWidth.current <= .medium {
                buyingPairView.spacing = 10
                make.width.equalTo(view.safeAreaLayoutGuide).offset(-40)
            } else {
                buyingPairView.spacing = 23
                make.width.equalTo(view.safeAreaLayoutGuide).offset(-56)
            }
        }
        payingSelectorView.load(currency: selectedCurrency)
        payingSelectorView.accessoryView = .activityIndicator
        payingSelectorView.addTarget(
            self,
            action: #selector(selectPaying(_:)),
            for: .touchUpInside
        )
        receivingSelectorView.accessoryView = .activityIndicator
        receivingSelectorView.addTarget(
            self,
            action: #selector(selectReceiving(_:)),
            for: .touchUpInside
        )
        
        let minimalAmountLabel = UILabel()
        minimalAmountLabel.textColor = R.color.text_secondary()?.withAlphaComponent(0.9)
        minimalAmountLabel.font = .preferredFont(forTextStyle: .caption1)
        minimalAmountLabel.adjustsFontForContentSizeCategory = true
        minimalAmountLabel.text = "Minimum 10 USD"
        minimalAmountLabel.alpha = 0
        reviewButtonStackView.addArrangedSubview(minimalAmountLabel)
        self.minimalAmountLabel = minimalAmountLabel
        reviewButtonStackViewBottomConstraint.constant = ScreenHeight.current <= .medium ? 10 : 18
        
        DispatchQueue.global().async { [weak self] in
            let id = AppGroupUserDefaults.Wallet.lastBuyingAssetID ?? AssetID.tronUSDT
            guard let placeholder = TokenDAO.shared.tokenItem(assetID: id) else {
                return
            }
            DispatchQueue.main.async {
                guard let self, self.selectedToken == nil else {
                    return
                }
                self.calculatedValueLabel.text = CurrencyFormatter.localizedString(
                    from: 0,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(placeholder.symbol)
                )
                self.receivingSelectorView.load(token: placeholder)
            }
        }
        
        view.isUserInteractionEnabled = false
        reloadTradingPairs()
    }
    
    override func toggleAmountIntent(_ sender: Any) {
        let inputValue = self.accumulator.decimal
        var accumulator: DecimalAccumulator
        switch amountIntent {
        case .byToken:
            amountIntent = .byFiatMoney
            accumulator = DecimalAccumulator(precision: selectedCurrency.precision)
            accumulator.decimal = NSDecimalNumber(decimal: inputValue)
                .rounding(accordingToBehavior: fiatMoneyAmountRoudingHandler)
                .decimalValue
        case .byFiatMoney:
            amountIntent = .byToken
            accumulator = DecimalAccumulator(precision: tokenPrecision)
            accumulator.decimal = NSDecimalNumber(decimal: inputValue)
                .rounding(accordingToBehavior: tokenAmountRoundingHandler)
                .decimalValue
        }
        self.accumulator = accumulator
    }
    
    override func reloadViews(inputAmount: Decimal) {
        guard let token = selectedToken else {
            return
        }
        let price = token.decimalUSDPrice * selectedCurrency.decimalRate
        
        formatter.alwaysShowsDecimalSeparator = accumulator.willInputFraction
        formatter.minimumFractionDigits = accumulator.fractions?.count ?? 0
        var inputAmountString = formatter.string(from: inputAmount as NSDecimalNumber) ?? "0"
        
        let isAmountGreaterThanMinimum: Bool
        switch amountIntent {
        case .byToken:
            tokenAmount = inputAmount
            fiatMoneyAmount = NSDecimalNumber(decimal: inputAmount * price)
                .rounding(accordingToBehavior: fiatMoneyAmountRoudingHandler)
                .decimalValue
            calculatedValueLabel.text = CurrencyFormatter.localizedString(
                from: fiatMoneyAmount,
                format: .fiatMoney,
                sign: .never,
                symbol: .custom(selectedCurrency.code)
            )
            inputAmountString.append(" " + token.symbol)
            isAmountGreaterThanMinimum = if let minimum = minimalAmount?.token {
                inputAmount >= minimum
            } else {
                false
            }
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
            inputAmountString.append(" " + selectedCurrency.code)
            isAmountGreaterThanMinimum = if let minimum = minimalAmount?.fiatMoney {
                inputAmount >= minimum
            } else {
                false
            }
        }
        
        amountLabel.text = inputAmountString
        minimalAmountLabel.textColor = if inputAmount == 0 || isAmountGreaterThanMinimum {
            R.color.text_secondary()!.withAlphaComponent(0.9)
        } else {
            R.color.error_red()
        }
        reviewButton.isEnabled = isAmountGreaterThanMinimum
    }
    
    override func replaceAmount(_ amount: Decimal) {
        accumulator.decimal = amount
    }
    
    override func review(_ sender: Any) {
        guard let token = selectedToken else {
            return
        }
        guard let amount = NumberFormatter.enUSPOSIXLocalizedDecimal.string(decimal: fiatMoneyAmount) else {
            return
        }
        let currency = selectedCurrency.code
        reviewButton.isBusy = true
        Task { [weak self] in
            do {
                let destination: String
                if let token = token as? Web3TokenItem {
                    let address = Web3AddressDAO.shared.address(
                        walletID: token.walletID,
                        chainID: token.chainID
                    )
                    guard let address else {
                        throw BuyingError.unsupportedChain
                    }
                    destination = address.destination
                } else {
                    let entries = try await SafeAPI.depositEntries(
                        assetID: token.assetID,
                        chainID: token.chainID
                    )
                    DepositEntryDAO.shared.replace(
                        entries: entries,
                        forChainWith: token.chainID
                    )
                    let primaryEntry = entries.first { entry in
                        entry.chainID == token.chainID && entry.isPrimary
                    }
                    guard let primaryEntry else {
                        throw BuyingError.unsupportedChain
                    }
                    destination = primaryEntry.destination
                }
                Logger.general.info(category: "Buy", message: "Buy \(amount) \(token.symbol) with \(currency), dst: \(destination)")
                let url = try await RouteAPI.rampURL(
                    amount: amount,
                    assetID: token.assetID,
                    currency: currency,
                    destination: destination
                )
                Logger.general.info(category: "Buy", message: "Redirect to \(url)")
                await MainActor.run {
                    guard let self else {
                        return
                    }
                    self.reviewButton.isBusy = false
                    let onramp = BuyTokenWebViewController(
                        title: R.string.localizable.buy_asset(token.symbol),
                        subtitle: nil,
                        url: url
                    )
                    self.present(onramp, animated: true)
                }
            } catch {
                Logger.general.info(category: "Buy", message: "\(error)")
                await MainActor.run {
                    guard let self else {
                        return
                    }
                    self.reviewButton.isBusy = false
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func selectPaying(_ sender: Any) {
        let selector = CurrencySelectorViewController(
            currencies: currencies,
            selectedCurrencyCode: selectedCurrency.code
        ) { currency in
            self.selectedCurrency = currency
            self.updateWithSelectedCurrency(currency)
            self.payingSelectorView.accessoryView = .activityIndicator
            self.reloadMinimalAmount()
            self.dismiss(animated: true)
            AppGroupUserDefaults.Wallet.lastBuyingCurrencyCode = currency.code
        }
        present(selector, animated: true, completion: nil)
    }
    
    @objc private func selectReceiving(_ sender: Any) {
        let selector = BuyTokenSelectorViewController(
            tokens: tokens,
            selectedAssetID: selectedToken?.assetID
        )
        selector.onSelected = { token in
            self.selectedToken = token
            self.updateWithSelectedToken(token)
            self.receivingSelectorView.accessoryView = .activityIndicator
            self.reloadMinimalAmount()
            self.dismiss(animated: true)
            AppGroupUserDefaults.Wallet.lastBuyingAssetID = token.assetID
        }
        present(selector, animated: true, completion: nil)
    }
    
    private func reloadTradingPairs() {
        Task { [weak self] in
            do {
                let profile = try await RouteAPI.profile()
                
                let context = PhoneNumberContext()
                let currencies = profile.currencies.compactMap { code in
                    Currency.map[code]
                }
                let currency: Currency? = {
                    let code = AppGroupUserDefaults.Wallet.lastBuyingCurrencyCode
                    ?? context.inferredCurrencyCode
                    ?? Currency.current.code
                    return currencies.first(where: { $0.code == code })
                    ?? currencies.first
                }()
                guard let currency else {
                    throw BuyingError.noAvailableCurrency
                }
                
                let allTokens = try await self?.tokens(assetIDs: profile.assetIDs) ?? [:]
                let tokens = profile.assetIDs.compactMap { id in
                    allTokens[id]
                }
                let token: any Token
                if let id = AppGroupUserDefaults.Wallet.lastBuyingAssetID, let lastBuying = allTokens[id] {
                    token = lastBuying
                } else if let firstToken = tokens.first {
                    token = firstToken
                } else {
                    throw BuyingError.noAvailableAsset
                }
                await MainActor.run {
                    guard let self else {
                        return
                    }
                    self.currencies = currencies
                    self.selectedCurrency = currency
                    self.updateWithSelectedCurrency(currency)
                    self.tokens = tokens
                    self.selectedToken = token
                    self.updateWithSelectedToken(token)
                    self.reloadMinimalAmount()
                    self.view.isUserInteractionEnabled = true
                }
            } catch {
                let worthRetrying = if let error = error as? MixinAPIError {
                    error.worthRetrying
                } else {
                    false
                }
                if worthRetrying {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.reloadTradingPairs()
                    }
                } else {
                    await MainActor.run {
                        guard let self else {
                            return
                        }
                        let alert = UIAlertController(
                            title: "Buying not available",
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        let ok = UIAlertAction(
                            title: R.string.localizable.ok(),
                            style: .default
                        ) { _ in
                            self.navigationController?.popViewController(animated: true)
                        }
                        alert.addAction(ok)
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    // Key is asset id
    private func tokens(assetIDs: [String]) async throws -> [String: any Token]  {
        var allTokens: [String: any Token]
        var assetIDs = Set(assetIDs)
        switch wallet {
        case .privacy:
            let localItems = TokenDAO.shared.tokenItems(with: assetIDs)
            for item in localItems {
                assetIDs.remove(item.assetID)
            }
            allTokens = localItems.reduce(into: [:]) { result, item in
                result[item.assetID] = item
            }
            
            if !assetIDs.isEmpty {
                let remoteTokens = try await SafeAPI.assets(ids: assetIDs)
                for token in remoteTokens {
                    let chain = ChainDAO.shared.chain(chainId: token.chainID)
                    let item = MixinTokenItem(token: token, balance: "0", isHidden: false, chain: chain)
                    allTokens[item.assetID] = item
                }
            }
        case .common(let wallet):
            let walletID = wallet.walletID
            let localItems = Web3TokenDAO.shared.tokenItems(walletID: walletID, ids: assetIDs)
            for item in localItems {
                assetIDs.remove(item.assetID)
            }
            allTokens = localItems.reduce(into: [:]) { result, item in
                result[item.assetID] = item
            }
            
            if !assetIDs.isEmpty {
                let availableChainIDs = Set(Web3Chain.all.map(\.chainID))
                let remoteTokens = try await SafeAPI.assets(ids: assetIDs)
                for token in remoteTokens where availableChainIDs.contains(token.chainID) {
                    let web3Token = Web3Token(
                        walletID: walletID,
                        assetID: token.assetID,
                        chainID: token.chainID,
                        assetKey: token.assetKey,
                        kernelAssetID: token.kernelAssetID,
                        symbol: token.symbol,
                        name: token.name,
                        precision: token.precision,
                        iconURL: token.iconURL,
                        amount: "0",
                        usdPrice: token.usdPrice,
                        usdChange: token.usdChange,
                        level: Web3Reputation.Level.verified.rawValue,
                    )
                    let chain = Web3ChainDAO.shared.chain(chainID: token.chainID)
                    let item = Web3TokenItem(token: web3Token, hidden: false, chain: chain)
                    allTokens[item.assetID] = item
                }
            }
        case .safe:
            allTokens = [:]
        }
        return allTokens
    }
    
    private func updateWithSelectedCurrency(_ currency: Currency) {
        payingSelectorView.load(currency: currency)
        fiatMoneyAmountRoudingHandler = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: currency.precision,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        switch amountIntent {
        case .byToken:
            replaceAmount(accumulator.decimal)
        case .byFiatMoney:
            let amount = self.accumulator.decimal
            var accumulator = DecimalAccumulator(precision: currency.precision)
            accumulator.decimal = amount
            self.accumulator = accumulator
        }
    }
    
    private func updateWithSelectedToken(_ token: any Token) {
        receivingSelectorView.load(token: token)
        tokenAmountRoundingHandler = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: tokenPrecision,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        switch amountIntent {
        case .byToken:
            let amount = self.accumulator.decimal
            var accumulator = DecimalAccumulator(precision: tokenPrecision)
            accumulator.decimal = amount
            self.accumulator = accumulator
        case .byFiatMoney:
            replaceAmount(accumulator.decimal)
        }
    }
    
    private func reloadMinimalAmount() {
        guard let token = selectedToken else {
            return
        }
        let currency = selectedCurrency
        let key = currency.code + token.assetID
        if let amount = minimalAmounts[key] {
            minimalAmount = amount
            payingSelectorView.accessoryView = .disclosure
            receivingSelectorView.accessoryView = .disclosure
            reloadViews(inputAmount: accumulator.decimal)
            updateMinimalLabel()
        } else {
            minimalAmount = nil
            minimalAmountLabel.alpha = 0
            RouteAPI.quote(
                currency: currency.code,
                assetID: token.assetID
            ) { [weak self, tokenAmountRoundingHandler] result in
                switch result {
                case .success(let quote):
                    guard let self else {
                        return
                    }
                    let minimalTokenAmount = quote.minimum / currency.decimalRate / token.decimalUSDPrice
                    let minimalAmount = MinimalAmount(
                        token: NSDecimalNumber(decimal: minimalTokenAmount)
                            .rounding(accordingToBehavior: tokenAmountRoundingHandler)
                            .decimalValue,
                        fiatMoney: quote.minimum
                    )
                    self.minimalAmounts[key] = minimalAmount
                    if currency.code == self.selectedCurrency.code,
                       token.assetID == self.selectedToken?.assetID
                    {
                        self.minimalAmount = minimalAmount
                        self.payingSelectorView.accessoryView = .disclosure
                        self.receivingSelectorView.accessoryView = .disclosure
                        self.reloadViews(inputAmount: accumulator.decimal)
                        self.updateMinimalLabel()
                    }
                case .failure(let error):
                    Logger.general.error(category: "Buy", message: "\(error)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.reloadMinimalAmount()
                    }
                }
            }
        }
    }
    
    private func updateMinimalLabel() {
        guard let minimalAmount else {
            return
        }
        let limitation = CurrencyFormatter.localizedString(
            from: minimalAmount.fiatMoney,
            format: .fiatMoney,
            sign: .never,
            symbol: .custom(selectedCurrency.code)
        )
        minimalAmountLabel.text = R.string.localizable.buying_limitation(limitation)
        minimalAmountLabel.alpha = 1
    }
    
}

extension BuyTokenInputAmountViewController {
    
    private enum BuyingError: Error {
        case noAvailableCurrency
        case noAvailableAsset
        case unsupportedChain
    }
    
    private struct MinimalAmount {
        let token: Decimal
        let fiatMoney: Decimal
    }
    
    private struct PhoneNumberContext {
        
        let regionCode: String?
        let inferredCurrencyCode: String?
        
        init() {
            let utility = PhoneNumberUtility()
            guard
                let phone = LoginManager.shared.account?.phone,
                let number = try? utility.parse(phone),
                let regionCode = utility.getRegionCode(of: number)
            else {
                self.regionCode = nil
                self.inferredCurrencyCode = nil
                return
            }
            
            let currencyCode: String?
            switch regionCode {
            case "AE":
                currencyCode = "AED"
            case "AU":
                currencyCode = "AUD"
            case "CA":
                currencyCode = "CAD"
            case "CN":
                currencyCode = "CNY"
            case "IE", "FR", "DE", "AT", "BE", "BG", "CY",
                "HR", "EE", "FI", "GR", "IT", "LV", "LT",
                "LU", "MT", "NL", "PT", "SK", "SI", "ES":
                currencyCode = "EUR"
            case "GB":
                currencyCode = "GBP"
            case "HK":
                currencyCode = "HKD"
            case "ID":
                currencyCode = "IDR"
            case "JP":
                currencyCode = "JPY"
            case "KR":
                currencyCode = "KRW"
            case "MY":
                currencyCode = "MYR"
            case "PH":
                currencyCode = "PHP"
            case "SG":
                currencyCode = "SGD"
            case "TR":
                currencyCode = "TRY"
            case "TW":
                currencyCode = "TWD"
            case "US":
                currencyCode = "USD"
            case "VN":
                currencyCode = "VND"
            default:
                currencyCode = nil
            }
            
            self.regionCode = regionCode
            self.inferredCurrencyCode = currencyCode
        }
        
    }
    
}
