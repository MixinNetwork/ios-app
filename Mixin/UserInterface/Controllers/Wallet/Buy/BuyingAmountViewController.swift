import UIKit
import StoreKit
import Alamofire
import PhoneNumberKit
import IdensicMobileSDK
import Frames
import Checkout3DS
import MixinServices

final class BuyingAmountViewController: UIViewController {
    
    private enum AmountIntent {
        case byPaying
        case byReceiving
    }
    
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var calculatedValueLabel: UILabel!
    @IBOutlet weak var selectorStackView: UIStackView!
    @IBOutlet weak var payingSelectorView: CompactComboBoxView!
    @IBOutlet weak var receivingSelectorView: CompactComboBoxView!
    @IBOutlet weak var decimalSeparatorButton: HighlightableButton!
    @IBOutlet weak var buyButton: RoundedButton!
    @IBOutlet weak var limitationLabel: UILabel!
    
    private let allowedPayments: Set<RouteProfile.Payment>
    private let allowedCurrencyCodes: Set<String>
    private let feedback = UIImpactFeedbackGenerator(style: .light)
    
    private lazy var sumsub = SNSMobileSDK(accessToken: "")
    
    private weak var cardSynchronizationRequest: Request?
    
    private var isKYCPassed: Bool
    private var asset: AssetItem
    private var assets: [AssetItem]
    private var ticker: BuyingTicker
    private var formatter: CheckoutAmountFormatter
    private var currency: Currency
    private var areCardsSynchronized = false
    
    private var amountIntent: AmountIntent = .byPaying {
        didSet {
            reloadSymbolLabel()
        }
    }
    
    private var payingAmount: Decimal {
        let amount = accumulator.decimal
        switch amountIntent {
        case .byPaying:
            return amount
        case .byReceiving:
            let merchant = amount * ticker.assetPrice
            let total = merchant / (1 - ticker.feePercent)
            let fee = total - merchant
            let roundedFee = NSDecimalNumber(decimal: fee)
                .rounding(accordingToBehavior: formatter.fiatMoneyCeilingHandler)
                .decimalValue
            let payingAmount = NSDecimalNumber(decimal: merchant + roundedFee)
                .rounding(accordingToBehavior: formatter.fiatMoneyCeilingHandler)
                .decimalValue
            return payingAmount
        }
    }
    
    private var accumulator: DecimalAccumulator {
        didSet {
            let amount = accumulator.decimal
            
            var amountString: String
            let fractionDigits = accumulator.fractions?.count ?? 0
            switch amountIntent {
            case .byPaying:
                amountString = formatter.fiatMoneyDisplayString(amount, minimumFractionDigits: fractionDigits)
            case .byReceiving:
                amountString = formatter.assetDisplayString(amount, minimumFractionDigits: fractionDigits)
            }
            if accumulator.willInputFraction {
                amountString.append(Locale.current.decimalSeparator ?? ".")
            }
            amountLabel.text = amountString
            
            recalculateEstimatedValue(inputAmount: amount)
            detect(payingAmount: payingAmount, exceedsLimitationFrom: ticker)
        }
    }
    
    init(
        isKYCInitialized: Bool,
        asset: AssetItem,
        assets: [AssetItem],
        allowedPayments: Set<RouteProfile.Payment>,
        allowedCurrencyCodes: Set<String>,
        currency: Currency,
        ticker: BuyingTicker
    ) {
        let formatter = CheckoutAmountFormatter(code: currency.code)
        
        self.isKYCPassed = isKYCInitialized
        self.allowedCurrencyCodes = allowedCurrencyCodes
        self.asset = asset
        self.assets = assets
        self.allowedPayments = allowedPayments
        self.ticker = ticker
        self.formatter = formatter
        self.currency = currency
        self.accumulator = DecimalAccumulator(maximumIntegerDigits: formatter.maximumIntegerDigits,
                                              maximumFractionDigits: formatter.maximumFractionDigits)
        
        let nib = R.nib.buyingAmountView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountLabel.font = .monospacedDigitSystemFont(ofSize: 64, weight: .regular)
        symbolLabel.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 0, right: 0)
        reloadSymbolLabel()
        reloadPaying()
        reloadReceiving()
        payingSelectorView.addTarget(self, action: #selector(selectPaying(_:)), for: .touchUpInside)
        receivingSelectorView.addTarget(self, action: #selector(selectReceiving(_:)), for: .touchUpInside)
        decimalSeparatorButton.setTitle(Locale.current.decimalSeparator ?? ".", for: .normal)
        reloadLimitationLabel(with: ticker)
        if isKYCPassed {
            cardSynchronizationRequest = RouteAPI.instruments { result in
                switch result {
                case .success(let cards):
                    PaymentCard.replace(cards)
                    self.areCardsSynchronized = true
                case .failure(let error):
                    self.areCardsSynchronized = false
                    Logger.general.error(category: "BuyingAmount", message: "Failed to load cards: \(error)")
                }
            }
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        selectorStackView.spacing = round(15 / 375 * view.bounds.width)
    }
    
    @IBAction func toggleAmountIntent(_ sender: Any) {
        switch amountIntent {
        case .byPaying:
            amountIntent = .byReceiving
            accumulator = DecimalAccumulator(maximumIntegerDigits: 20, maximumFractionDigits: 8)
        case .byReceiving:
            amountIntent = .byPaying
            accumulator = DecimalAccumulator(maximumIntegerDigits: formatter.maximumIntegerDigits,
                                             maximumFractionDigits: formatter.maximumFractionDigits)
        }
    }
    
    @IBAction func inputValue(_ sender: DecimalButton) {
        accumulator.append(value: sender.value)
    }
    
    @IBAction func inputDecimalSeparator(_ sender: Any) {
        guard formatter.maximumFractionDigits > 0 else {
            return
        }
        accumulator.appendDecimalSeparator()
    }
    
    @IBAction func deleteBackwards(_ sender: Any) {
        accumulator.deleteBackwards()
    }
    
    @IBAction func generateInputFeedback(_ sender: Any) {
        feedback.impactOccurred()
    }
    
    @IBAction func buy(_ sender: Any) {
        if isKYCPassed {
            cardSynchronizationRequest?.cancel()
            let order = BuyCryptoOrder(asset: asset,
                                       paymentAmount: payingAmount,
                                       paymentCurrency: currency.code,
                                       formatter: formatter,
                                       initialTicker: ticker)
            let selector = PaymentSourceViewController(order: order, payments: allowedPayments)
            selector.synchronizeCardsBeforePresentingSelector = !areCardsSynchronized
            let container = ContainerViewController.instance(viewController: selector, title: R.string.localizable.select_payment_method())
            navigationController?.pushViewController(container, animated: true)
        } else {
            guard sumsub.isReady else {
                alert(R.string.localizable.sumsub_not_ready(), message: sumsub.verboseStatus)
                return
            }
            sumsub.setTokenExpirationHandler { onComplete in
                RouteAPI.sumsubToken() { result in
                    switch result {
                    case let .success(token):
                        onComplete(token)
                    case .failure:
                        onComplete(nil)
                    }
                }
            }
            sumsub.setDismissHandler { [weak self] sdk, _ in
                Logger.general.info(category: "BuyingAmount", message: "Status: \(sdk.status.rawValue), controllers: \(self?.navigationController?.viewControllers ?? [])")
                switch sdk.status {
                case .ready, .failed, .initial, .incomplete, .actionCompleted:
                    self?.navigationController?.dismiss(animated: true)
                case .pending, .temporarilyDeclined, .finallyRejected:
                    if
                        let self,
                        let navigationController = self.navigationController,
                        let container = navigationController.topViewController as? ContainerViewController,
                        container.viewController == self
                    {
                        navigationController.popViewController(animated: false)
                        navigationController.dismiss(animated: true)
                    }
                case .approved:
                    if let self {
                        self.isKYCPassed = true
                        self.navigationController?.dismiss(animated: true)
                    }
                }
            }
            if let navigationController {
                sumsub.present(from: navigationController)
            }
        }
    }
    
    @objc private func selectPaying(_ sender: Any) {
        let assetID = self.asset.assetId
        let currencies = Currency.all.filter { currency in
            allowedCurrencyCodes.contains(currency.code)
        }
        let selector = CurrencySelectorViewController(currencies: currencies, selectedCurrencyCode: currency.code) { currency in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            RouteAPI.ticker(amount: 0, assetID: assetID, currency: currency.code, completion: { result in
                switch result {
                case .success(let ticker):
                    let formatter = CheckoutAmountFormatter(code: currency.code)
                    self.ticker = ticker
                    self.formatter = formatter
                    self.currency = currency
                    self.accumulator = DecimalAccumulator(maximumIntegerDigits: formatter.maximumIntegerDigits,
                                                          maximumFractionDigits: formatter.maximumFractionDigits)
                    self.reloadPaying()
                    self.reloadLimitationLabel(with: ticker)
                    self.reloadSymbolLabel()
                    self.dismiss(animated: true)
                    hud.hide()
                    AppGroupUserDefaults.User.lastBuyingCurrencyCode = currency.code
                case .failure(let error):
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            })
        }
        present(selector, animated: true, completion: nil)
    }
    
    @objc private func selectReceiving(_ sender: Any) {
        let selector = TransferTypeViewController()
        selector.delegate = self
        selector.assets = assets
        selector.asset = asset
        present(selector, animated: true, completion: nil)
    }
    
    private func reloadPaying() {
        payingSelectorView.iconImageView.image = currency.icon
        payingSelectorView.text = currency.code
    }
    
    private func reloadReceiving() {
        receivingSelectorView.iconImageView.sd_cancelCurrentImageLoad()
        receivingSelectorView.iconImageView.sd_setImage(with: URL(string: asset.iconUrl),
                                                        placeholderImage: nil,
                                                        context: assetIconContext)
        receivingSelectorView.text = asset.symbol
        buyButton.setTitle(R.string.localizable.buy_asset(asset.symbol), for: .normal)
    }
    
    private func reloadLimitationLabel(with ticker: BuyingTicker) {
        let minimum = formatter.fiatMoneyDisplayString(ticker.minimum) + " " + currency.code
        let maximum = formatter.fiatMoneyDisplayString(ticker.maximum) + " " + currency.code
        limitationLabel.text = R.string.localizable.buying_limitation(minimum, maximum)
    }
    
    private func detect(payingAmount: Decimal, exceedsLimitationFrom ticker: BuyingTicker) {
        if payingAmount >= ticker.minimum && payingAmount <= ticker.maximum {
            buyButton.isEnabled = true
            limitationLabel.textColor = R.color.text()
        } else {
            buyButton.isEnabled = false
            if payingAmount == 0 {
                limitationLabel.textColor = R.color.text()
            } else {
                limitationLabel.textColor = R.color.red()
            }
        }
    }
    
    private func reloadSymbolLabel() {
        switch amountIntent {
        case .byPaying:
            symbolLabel.text = currency.code
        case .byReceiving:
            symbolLabel.text = asset.symbol
        }
    }
    
    private func recalculateEstimatedValue(inputAmount: Decimal) {
        switch amountIntent {
        case .byPaying:
            if inputAmount == 0 {
                calculatedValueLabel.text = "0 " + asset.symbol
            } else {
                let receivingAmount = inputAmount / ticker.assetPrice
                let receivingAmountString = formatter.assetDisplayString(receivingAmount)
                calculatedValueLabel.text = "≈ \(receivingAmountString) \(asset.symbol)"
            }
        case .byReceiving:
            if inputAmount == 0 {
                calculatedValueLabel.text = "0 " + currency.code
            } else {
                let payingAmountString = formatter.fiatMoneyDisplayString(payingAmount)
                calculatedValueLabel.text = "≈ \(payingAmountString) \(currency.code)"
            }
        }
    }
    
}

extension BuyingAmountViewController: TransferTypeViewControllerDelegate {
    
    func transferTypeViewController(_ viewController: TransferTypeViewController, didSelectAsset asset: AssetItem) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        RouteAPI.ticker(amount: 0, assetID: asset.assetId, currency: currency.code, completion: { result in
            switch result {
            case .success(let ticker):
                self.asset = asset
                self.ticker = ticker
                self.reloadLimitationLabel(with: ticker)
                self.reloadReceiving()
                self.reloadSymbolLabel()
                self.recalculateEstimatedValue(inputAmount: self.accumulator.decimal)
                self.detect(payingAmount: self.payingAmount, exceedsLimitationFrom: ticker)
                self.dismiss(animated: true)
                hud.hide()
                AppGroupUserDefaults.User.lastBuyingAssetID = asset.assetId
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        })
    }
    
}


extension BuyingAmountViewController {
    
    private static let phoneNumberKit = PhoneNumberKit()
    
    static func buy(on viewController: UIViewController, completion: @escaping (Error?) -> Void) {
        let isRegionAvailable: Bool
        if let deviceRegionCode = Locale.current.regionCode?.uppercased() {
            let availableRegionCodes: Set<String> = [
                "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU",
                "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES",
                "SE", "IS", "LI", "NO"
            ]
            let isDeviceLocaleInRegion = availableRegionCodes.contains(deviceRegionCode)
            let isPhoneNumberOutOfRegion: Bool
            if let phone = LoginManager.shared.account?.phone, let number = try? phoneNumberKit.parse(phone), let regionCode = phoneNumberKit.getRegionCode(of: number)?.uppercased() {
                isPhoneNumberOutOfRegion = !availableRegionCodes.contains(regionCode)
            } else {
                isPhoneNumberOutOfRegion = false
            }
            isRegionAvailable = isDeviceLocaleInRegion && !isPhoneNumberOutOfRegion
        } else {
            isRegionAvailable = false
        }
        guard isRegionAvailable else {
            let unavailable = BuyingUnavailableViewController(state: .unavailableRegion)
            let container = ContainerViewController.instance(viewController: unavailable, title: "")
            container.modalPresentationStyle = .fullScreen
            viewController.present(container, animated: true)
            completion(nil)
            return
        }
        
        Task {
            do {
                let profile = try await RouteAPI.profile()
                switch profile.kycState {
                case .retry:
                    await MainActor.run {
                        let unavailable = BuyingUnavailableViewController(state: .kycRetry)
                        let container = ContainerViewController.instance(viewController: unavailable, title: "")
                        viewController.navigationController?.pushViewController(container, animated: true)
                        completion(nil)
                    }
                case .pending:
                    await MainActor.run {
                        let unavailable = BuyingUnavailableViewController(state: .kycPending)
                        let container = ContainerViewController.instance(viewController: unavailable, title: "")
                        container.modalPresentationStyle = .fullScreen
                        viewController.present(container, animated: true)
                        completion(nil)
                    }
                case .blocked:
                    await MainActor.run {
                        let unavailable = BuyingUnavailableViewController(state: .kycBlocked)
                        let container = ContainerViewController.instance(viewController: unavailable, title: "")
                        container.modalPresentationStyle = .fullScreen
                        viewController.present(container, animated: true)
                        completion(nil)
                    }
                case .initial, .success, .ignore:
                    guard !profile.supportPayments.isEmpty else {
                        throw BuyingError.noAvailablePayment
                    }
                    
                    let allowedCurrencyCodes = Set(profile.currencies)
                    let currencies = Currency.all.filter { currency in
                        allowedCurrencyCodes.contains(currency.code)
                    }
                    let currency: Currency
                    if let code = AppGroupUserDefaults.User.lastBuyingCurrencyCode, let lastChoice = currencies.first(where: { $0.code == code }) {
                        currency = lastChoice
                    } else if let code = phoneNumberInferredCurrencyCode(), let inferred = currencies.first(where: { $0.code == code }) {
                        currency = inferred
                    } else if allowedCurrencyCodes.contains(Currency.current.code) {
                        currency = .current
                    } else if let first = currencies.first {
                        currency = first
                    } else {
                        throw BuyingError.noAvailableCurrency
                    }
                    
                    var items: [AssetItem] = []
                    for id in profile.assetIDs {
                        if let item = AssetDAO.shared.getAsset(assetId: id) {
                            items.append(item)
                        } else if let asset = try? await AssetAPI.asset(assetId: id), let chain = try? await AssetAPI.chain(chainId: asset.chainId) {
                            items.append(AssetItem(asset: asset, chain: chain))
                        }
                    }
                    let asset: AssetItem
                    if let id = AppGroupUserDefaults.User.lastBuyingAssetID, let item = items.first(where: { $0.assetId == id }) {
                        asset = item
                    } else if let item = items.first {
                        asset = item
                    } else {
                        throw BuyingError.noAvailableAsset
                    }
                    
                    let ticker = try await RouteAPI.ticker(amount: 0, assetID: asset.assetId, currency: currency.code)
                    await MainActor.run {
                        let buy = BuyingAmountViewController(isKYCInitialized: profile.kycState != .initial,
                                                             asset: asset,
                                                             assets: items,
                                                             allowedPayments: profile.supportPayments,
                                                             allowedCurrencyCodes: allowedCurrencyCodes,
                                                             currency: currency,
                                                             ticker: ticker)
                        let container = ContainerViewController.instance(viewController: buy, title: "")
                        viewController.navigationController?.pushViewController(container, animated: true)
                        completion(nil)
                    }
                }
            } catch {
                await MainActor.run {
                    completion(error)
                }
            }
        }
    }
    
    private static func phoneNumberInferredCurrencyCode() -> String? {
        guard let numberString = LoginManager.shared.account?.phone else {
            return nil
        }
        let phoneNumberKit = PhoneNumberKit()
        guard let number = try? phoneNumberKit.parse(numberString) else {
            return nil
        }
        guard let regionCode = phoneNumberKit.getRegionCode(of: number) else {
            return nil
        }
        switch regionCode {
        case "AE":
            return "AED"
        case "AU":
            return "AUD"
        case "CA":
            return "CAD"
        case "CN":
            return "CNY"
        case "IE", "FR", "DE", "AT", "BE", "BG", "CY", "HR", "EE", "FI", "GR", "IT", "LV", "LT", "LU", "MT", "NL", "PT", "SK", "SI", "ES":
            return "EUR"
        case "GB":
            return "GBP"
        case "HK":
            return "HKD"
        case "ID":
            return "IDR"
        case "JP":
            return "JPY"
        case "KR":
            return "KRW"
        case "MY":
            return "MYR"
        case "PH":
            return "PHP"
        case "SG":
            return "SGD"
        case "TR":
            return "TRY"
        case "TW":
            return "TWD"
        case "US":
            return "USD"
        case "VN":
            return "VND"
        default:
            return nil
        }
    }
    
}

fileprivate struct DecimalAccumulator {
    
    private let maximumIntegerDigits: Int
    private let maximumFractionDigits: Int
    
    private(set) var integers: [UInt8] = [0]
    private(set) var fractions: [UInt8]? = nil
    
    var willInputFraction: Bool {
        fractions?.isEmpty ?? false
    }
    
    var decimal: Decimal {
        var result: Decimal = 0
        for (index, integer) in integers.enumerated() {
            let power = pow(10, integers.count - index - 1)
            let value = Decimal(integer) * power
            result += value
        }
        if let fractions {
            for (index, fraction) in fractions.enumerated() {
                let power = 1 / pow(10, index + 1)
                let value = Decimal(fraction) * power
                result += value
            }
        }
        return result
    }
    
    init(maximumIntegerDigits: Int, maximumFractionDigits: Int) {
        self.maximumIntegerDigits = maximumIntegerDigits
        self.maximumFractionDigits = maximumFractionDigits
    }
    
    mutating func append(value: UInt8) {
        assert(value < 10)
        if let fractions {
            if fractions.count + 1 <= maximumFractionDigits {
                self.fractions!.append(value)
            }
        } else {
            if integers == [0] {
                integers = [value]
            } else if integers.count + 1 <= maximumIntegerDigits {
                integers.append(value)
            }
        }
    }
    
    mutating func appendDecimalSeparator() {
        if fractions == nil {
            fractions = []
        }
    }
    
    mutating func deleteBackwards() {
        if let fractions {
            switch fractions.count {
            case 0:
                self.fractions = nil
            case 1:
                self.fractions = []
            default:
                self.fractions!.removeLast()
            }
        } else {
            if integers.count == 1 {
                integers = [0]
            } else {
                integers.removeLast()
            }
        }
    }
    
}
