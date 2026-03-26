import UIKit
import MixinServices

final class OpenPerpetualPositionViewController: UIViewController {
    
    private enum Multiplier {
        case fixed(Decimal)
        case max
        case custom(Decimal)
    }
    
    @IBOutlet weak var contentView: UIView!
    
    @IBOutlet weak var tokenIconView: PlainTokenIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    
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
    
    @IBOutlet weak var leverageView: UIView!
    @IBOutlet weak var leverageTitleLabel: UILabel!
    @IBOutlet weak var leverageMultiplierTextField: UITextField!
    @IBOutlet weak var leverageMultipliersCollectionView: UICollectionView!
    @IBOutlet weak var leverageMultipliersCollectionViewLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var leverageMultipliersCollectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var changeSimulationLabel: UILabel!
    
    @IBOutlet weak var orderValueTitleLabel: UILabel!
    @IBOutlet weak var orderValueContentLabel: UILabel!
    @IBOutlet weak var liquidationPriceTitleLabel: UILabel!
    @IBOutlet weak var liquidationPriceContentLabel: UILabel!
    
    @IBOutlet weak var reviewButtonWrapperView: UIView!
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var reviewButton: ConfigurationBasedBusyButton!
    
    private let wallet: Wallet
    private let side: PerpetualOrderSide
    private let viewModel: PerpetualMarketViewModel
    private let amountValidator: AmountValidator
    private let multipliers: [Multiplier]
    private let cellReuseIdentifier = "l"
    
    private weak var contentSizeObserver: NSKeyValueObservation?
    
    private var marginAmount: Decimal = 0
    
    private var marginTokens: [MixinTokenItem] = []
    private var marginToken: MixinTokenItem? {
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
                    },
                    .init(title: "50%") { [weak self] in
                        self?.inputAmount(withBalanceMultipliedBy: 0.5)
                    },
                    .init(title: R.string.localizable.max()) { [weak self] in
                        self?.inputAmount(withBalanceMultipliedBy: 1)
                    },
                ]
                accessoryView.onDone = { [weak textField=marginAmountTextField] in
                    textField?.resignFirstResponder()
                }
                marginAmountTextField.inputAccessoryView = accessoryView
            }
        }
    }
    
    private var leverageMultiplier: Decimal
    
    init(
        wallet: Wallet,
        side: PerpetualOrderSide,
        viewModel: PerpetualMarketViewModel,
    ) {
        var leverageMultiplier = Decimal(
            AppGroupUserDefaults.Wallet.lastPerpsLeverageMultiplier[viewModel.market.marketID] ?? 10
        )
        if leverageMultiplier > viewModel.maxLeverageMultiplier {
            leverageMultiplier = viewModel.maxLeverageMultiplier < 10 ? 2 : 10
        }
        
        self.wallet = wallet
        self.side = side
        self.viewModel = viewModel
        self.amountValidator = AmountValidator(market: viewModel.market)
        self.multipliers = [
            .fixed(2),
            .fixed(5),
            .fixed(10),
            .fixed(20),
            .max,
            .custom(-1),
        ].filter { leverage in
            switch leverage {
            case .fixed(let leverage):
                leverage <= viewModel.maxLeverageMultiplier
            case .max, .custom:
                true
            }
        }
        self.leverageMultiplier = leverageMultiplier
        let nib = R.nib.openPerpetualPositionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = R.string.localizable.open_position()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        tokenIconView.setIcon(tokenIconURL: viewModel.iconURL)
        titleLabel.text = switch side {
        case .long:
            R.string.localizable.long_asset(viewModel.market.tokenSymbol)
        case .short:
            R.string.localizable.short_asset(viewModel.market.tokenSymbol)
        }
        priceLabel.text = R.string.localizable.current_price(viewModel.price)
        
        let infoLabels: [UILabel] = [
            marginTitleLabel,
            marginNetworkLabel,
            leverageTitleLabel,
            orderValueTitleLabel,
            orderValueContentLabel,
            liquidationPriceTitleLabel,
            liquidationPriceContentLabel,
        ]
        for label in infoLabels {
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
        
        marginView.layer.cornerRadius = 8
        marginView.layer.masksToBounds = true
        marginContentStackView.setCustomSpacing(0, after: marginTokenSelectorStackView)
        marginTitleLabel.text = R.string.localizable.amount()
        marginTokenFooterStackView.setCustomSpacing(0, after: marginTokenBalanceButton)
        marginTokenBalanceButton.titleLabel?.adjustsFontForContentSizeCategory = true
        marginTokenDepositButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFont.preferredFont(forTextStyle: .caption1)
            return AttributedString(R.string.localizable.add(), attributes: attributes)
        }()
        marginTokenDepositButton.titleLabel?.adjustsFontForContentSizeCategory = true
        marginLoadingView.startAnimating()
        
        leverageView.layer.cornerRadius = 8
        leverageView.layer.masksToBounds = true
        leverageTitleLabel.text = R.string.localizable.leverage()
        
        orderValueTitleLabel.text = R.string.localizable.position_size()
        liquidationPriceTitleLabel.text = R.string.localizable.liquidation_price()
        
        leverageMultipliersCollectionViewLayout.itemSize = UICollectionViewFlowLayout.automaticSize
        leverageMultipliersCollectionView.register(LeverageCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)
        leverageMultipliersCollectionView.contentInset = UIEdgeInsets(top: 7, left: 16, bottom: 7, right: 16)
        leverageMultipliersCollectionView.dataSource = self
        leverageMultipliersCollectionView.delegate = self
        contentSizeObserver = leverageMultipliersCollectionView.observe(
            \.contentSize,
             options: [.new]
        ) { [weak self] (_, change) in
            guard let newValue = change.newValue, let self else {
                return
            }
            if leverageMultipliersCollectionViewHeightConstraint.constant != newValue.height {
                self.leverageMultipliersCollectionViewHeightConstraint.constant = newValue.height
                self.view.layoutIfNeeded()
            }
        }
        
        reviewButtonWrapperView.snp.makeConstraints { make in
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
                .priority(.high)
        }
        reviewButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.review(),
            attributes: {
                var container = AttributeContainer()
                container.font = .callout
                return container
            }()
        )
        reviewButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        leverageMultipliersCollectionView.reloadData()
        inputLeverageMultiplier(value: leverageMultiplier)
        updateDescriptions(
            marginAmount: 0,
            leverageMultiplier: leverageMultiplier,
            underlyingAsset: viewModel
        )
        reloadMarginTokens()
    }
    
    @IBAction func editMarginAmount(_ textField: UITextField) {
        let amount: Decimal = if let text = textField.text {
            Decimal(string: text, locale: .current) ?? 0
        } else {
            0
        }
        self.marginAmount = amount
        updateDescriptions(
            marginAmount: amount,
            leverageMultiplier: leverageMultiplier,
            underlyingAsset: viewModel
        )
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
    }
    
    @IBAction func depositMarginToken(_ sender: Any) {
        guard let marginToken else {
            return
        }
        let selector = AddTokenMethodSelectorViewController(token: marginToken)
        selector.delegate = self
        present(selector, animated: true)
    }
    
    @IBAction func presentManual(_ sender: Any) {
        let manual = PerpsManual.viewController(initialPage: .size)
        present(manual, animated: true)
    }
    
    @IBAction func review(_ sender: ConfigurationBasedBusyButton) {
        guard let marginToken else {
            return
        }
        marginAmountTextField.resignFirstResponder()
        let request = OpenPerpetualOrderRequest(
            assetID: marginToken.assetID,
            marketID: viewModel.market.marketID,
            side: side,
            amount: TokenAmountFormatter.string(from: marginAmount),
            leverage: (leverageMultiplier as NSDecimalNumber).intValue,
            walletID: wallet.tradingWalletID,
            destination: nil
        )
        sender.isBusy = true
        RouteAPI.openPerpsOrder(
            orderRequest: request
        ) { [weak self, wallet, viewModel, leverageMultiplier] result in
            switch result {
            case .success(let response):
                guard let url = URL(string: response.paymentURL) else {
                    if let self {
                        self.showError(description: R.string.localizable.invalid_payment_link())
                        self.reviewButton.isBusy = false
                    }
                    return
                }
                let context = Payment.PerpsContext(
                    wallet: wallet,
                    viewModel: viewModel,
                    side: request.side,
                    leverageMultiplier: leverageMultiplier
                )
                let source: UrlWindow.Source = .perps(context: context) { description in
                    guard let self else {
                        return
                    }
                    if let description {
                        self.showError(description: description)
                    }
                    self.reviewButton.isBusy = false
                }
                _ = UrlWindow.checkUrl(url: url, from: source)
            case .failure(let error):
                guard let self else {
                    return
                }
                self.showError(description: error.localizedDescription)
                self.reviewButton.isBusy = false
            }
        }
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "open_perps_position"])
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
    
    private func inputAmount(withBalanceMultipliedBy balanceMultiplier: Decimal) {
        guard let token = marginToken else {
            return
        }
        marginAmount = token.decimalBalance * balanceMultiplier
        marginAmountTextField.text = CurrencyFormatter.localizedString(
            from: marginAmount,
            format: .precision,
            sign: .never,
        )
        updateDescriptions(
            marginAmount: marginAmount,
            leverageMultiplier: leverageMultiplier,
            underlyingAsset: viewModel
        )
    }
    
    private func inputLeverageMultiplier(value: Decimal) {
        var presetMultiplierIndex: Int?
        var customMultiplierIndex: Int?
        for (index, multiplier) in multipliers.enumerated() {
            switch multiplier {
            case .fixed(let v) where value == v:
                presetMultiplierIndex = index
            case .max where value == viewModel.maxLeverageMultiplier:
                presetMultiplierIndex = index
            case .custom:
                customMultiplierIndex = index
            default:
                break
            }
        }
        guard let item = presetMultiplierIndex ?? customMultiplierIndex else {
            return
        }
        self.leverageMultiplier = value
        leverageMultiplierTextField.text = PerpetualLeverage.stringRepresentation(multiplier: value)
        leverageMultipliersCollectionView.selectItem(
            at: IndexPath(item: item, section: 0),
            animated: false,
            scrollPosition: []
        )
        updateDescriptions(
            marginAmount: marginAmount,
            leverageMultiplier: value,
            underlyingAsset: viewModel
        )
        AppGroupUserDefaults.Wallet.lastPerpsLeverageMultiplier[viewModel.market.marketID] = (value as NSDecimalNumber).intValue
    }
    
    private func updateDescriptions(
        marginAmount: Decimal,
        leverageMultiplier: Decimal,
        underlyingAsset: PerpetualMarketViewModel
    ) {
        if marginAmount != 0, let marginToken {
            if marginAmount > marginToken.decimalBalance {
                showError(description: R.string.localizable.insufficient_balance())
                reviewButton.isEnabled = false
            } else {
                let result = amountValidator.validate(
                    amount: marginAmount,
                    symbol: marginToken.symbol
                )
                switch result {
                case .valid:
                    showError(description: nil)
                    reviewButton.isEnabled = true
                case .invalid(let reason):
                    showError(description: reason)
                    reviewButton.isEnabled = false
                }
            }
        } else {
            showError(description: nil)
            reviewButton.isEnabled = false
        }
        changeSimulationLabel.text = PerpetualChangeSimulation.profit(
            side: side,
            margin: marginAmount,
            leverageMultiplier: leverageMultiplier,
            priceChangePercent: 0.01
        )
        orderValueContentLabel.text = CurrencyFormatter.localizedString(
            from: marginAmount * leverageMultiplier / underlyingAsset.decimalPrice,
            format: .precision,
            sign: .never,
            symbol: .custom(underlyingAsset.market.tokenSymbol)
        )
        if marginAmount > 0 {
            let liquidationPrice = switch side {
            case .long:
                underlyingAsset.decimalPrice * (1 - 1 / leverageMultiplier)
            case .short:
                underlyingAsset.decimalPrice * (1 + 1 / leverageMultiplier)
            }
            liquidationPriceContentLabel.text = CurrencyFormatter.localizedString(
                from: liquidationPrice * Currency.current.decimalRate,
                format: .fiatMoneyPrice,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            liquidationPriceContentLabel.text = "-"
        }
    }
    
    private func showError(description: String?) {
        if let description {
            errorDescriptionLabel.text = description
            errorDescriptionLabel.isHidden = false
        } else {
            errorDescriptionLabel.isHidden = true
        }
    }
    
}

extension OpenPerpetualPositionViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension OpenPerpetualPositionViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        multipliers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as! LeverageCell
        let leverage = multipliers[indexPath.item]
        cell.label.text = switch leverage {
        case .fixed(let leverage):
            PerpetualLeverage.stringRepresentation(multiplier: leverage)
        case .max:
            R.string.localizable.max()
        case .custom:
            R.string.localizable.custom()
        }
        return cell
    }
    
}

extension OpenPerpetualPositionViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch multipliers[indexPath.item] {
        case .custom:
            marginAmountTextField.resignFirstResponder()
            let input = LeverageMultiplierInputViewController(
                side: side,
                maxMultiplier: viewModel.maxLeverageMultiplier,
                marginAmount: marginAmount,
                currentMultiplier: leverageMultiplier
            )
            input.onInput = { [weak self] (leverage) in
                self?.inputLeverageMultiplier(value: leverage)
            }
            present(input, animated: true)
            return false
        default:
            return true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        switch multipliers[indexPath.item] {
        case .custom:
            marginAmountTextField.resignFirstResponder()
            let input = LeverageMultiplierInputViewController(
                side: side,
                maxMultiplier: viewModel.maxLeverageMultiplier,
                marginAmount: marginAmount,
                currentMultiplier: leverageMultiplier
            )
            input.onInput = { [weak self] (leverage) in
                self?.inputLeverageMultiplier(value: leverage)
            }
            present(input, animated: true)
        default:
            break
        }
        return false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        marginAmountTextField.resignFirstResponder()
        switch multipliers[indexPath.item] {
        case .fixed(let leverage):
            inputLeverageMultiplier(value: leverage)
        case .max:
            inputLeverageMultiplier(value: viewModel.maxLeverageMultiplier)
        case .custom:
            break
        }
    }
    
}

extension OpenPerpetualPositionViewController: AddTokenMethodSelectorViewController.Delegate {
    
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

extension OpenPerpetualPositionViewController {
    
    private final class LeverageCell: UICollectionViewCell {
        
        weak var label: InsetLabel!
        
        override var isSelected: Bool {
            didSet {
                updateColors(isSelected: isSelected)
            }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadSubview()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadSubview()
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            label.layer.cornerRadius = bounds.height / 2
        }
        
        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                updateColors(isSelected: isSelected)
            }
        }
        
        private func loadSubview() {
            let label = InsetLabel()
            label.contentInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            label.layer.borderWidth = 1
            label.layer.masksToBounds = true
            label.setFont(
                scaledFor: .systemFont(ofSize: 12, weight: .medium),
                adjustForContentSize: true
            )
            contentView.addSubview(label)
            label.snp.makeEdgesEqualToSuperview()
            self.label = label
            updateColors(isSelected: false)
        }
        
        private func updateColors(isSelected: Bool) {
            if isSelected {
                label.layer.borderColor = R.color.theme()!.cgColor
                label.textColor = R.color.theme()
                label.backgroundColor = R.color.background_selection()
            } else {
                label.layer.borderColor = R.color.line()!.cgColor
                label.textColor = R.color.text()
                label.backgroundColor = .clear
            }
        }
        
    }
    
    private final class AmountValidator {
        
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
