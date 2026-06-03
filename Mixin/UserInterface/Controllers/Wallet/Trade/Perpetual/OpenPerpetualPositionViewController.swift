import UIKit
import MixinServices

final class OpenPerpetualPositionViewController: PerpsMarginInputViewController {
    
    private enum Multiplier {
        case fixed(Decimal)
        case max
        case custom(Decimal)
    }
    
    @IBOutlet weak var contentView: UIView!
    
    @IBOutlet weak var tokenIconView: PlainTokenIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    
    @IBOutlet weak var leverageView: UIView!
    @IBOutlet weak var leverageTitleLabel: UILabel!
    @IBOutlet weak var leverageMultiplierTextField: UITextField!
    @IBOutlet weak var leverageMultipliersCollectionView: UICollectionView!
    @IBOutlet weak var leverageMultipliersCollectionViewLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var leverageMultipliersCollectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var changeSimulationLabel: UILabel!
    
    @IBOutlet weak var takeProfitTitleLabel: UILabel!
    @IBOutlet weak var takeProfitContentLabel: UILabel!
    @IBOutlet weak var stopLossTitleLabel: UILabel!
    @IBOutlet weak var stopLossContentLabel: UILabel!
    @IBOutlet weak var orderValueTitleLabel: UILabel!
    @IBOutlet weak var orderValueContentLabel: UILabel!
    @IBOutlet weak var liquidationPriceTitleLabel: UILabel!
    @IBOutlet weak var liquidationPriceContentLabel: UILabel!
    @IBOutlet weak var liquidationPriceActivityIndicator: ActivityIndicatorView!
    
    @IBOutlet weak var reviewButtonWrapperView: UIView!
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var reviewButton: ConfigurationBasedBusyButton!
    
    private let wallet: Wallet
    private let side: PerpetualOrderSide
    private let viewModel: PerpetualMarketViewModel
    private let amountValidator: AmountValidator
    private let multipliers: [Multiplier]
    private let liquidationPriceRequester: OpenPerpsPositionLiquidationPriceRequester
    private let cellReuseIdentifier = "l"
    
    private weak var contentSizeObserver: NSKeyValueObservation?
    
    private var leverageMultiplier: Decimal
    
    private var liquidationPrice: Decimal?
    
    private var takeProfitPrice: Decimal? {
        didSet {
            if let takeProfitPrice {
                takeProfitContentLabel.text = takeProfitPrice.formatted(
                    viewModel.userDisplayPriceFormatStyle
                )
                takeProfitContentLabel.textColor = MarketColor.rising.uiColor
            } else {
                takeProfitContentLabel.text = R.string.localizable.add()
                takeProfitContentLabel.textColor = R.color.theme()
            }
        }
    }
    
    private var stopLossPrice: Decimal? {
        didSet {
            if let stopLossPrice {
                stopLossContentLabel.text = stopLossPrice.formatted(
                    viewModel.userDisplayPriceFormatStyle
                )
                stopLossContentLabel.textColor = MarketColor.falling.uiColor
            } else {
                stopLossContentLabel.text = R.string.localizable.add()
                stopLossContentLabel.textColor = R.color.theme()
            }
        }
    }
    
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
        self.liquidationPriceRequester = OpenPerpsPositionLiquidationPriceRequester(
            marketID: viewModel.market.marketID,
            side: side
        )
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
            leverageTitleLabel,
            takeProfitTitleLabel,
            takeProfitContentLabel,
            stopLossTitleLabel,
            stopLossContentLabel,
            orderValueTitleLabel,
            orderValueContentLabel,
            liquidationPriceTitleLabel,
            liquidationPriceContentLabel,
        ]
        for label in infoLabels {
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
        
        leverageView.layer.cornerRadius = 8
        leverageView.layer.masksToBounds = true
        leverageTitleLabel.text = R.string.localizable.leverage()
        
        orderValueTitleLabel.text = R.string.localizable.position_size()
        liquidationPriceTitleLabel.text = R.string.localizable.liquidation_price()
        
        leverageMultiplierTextField.delegate = self
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
        
        takeProfitTitleLabel.text = R.string.localizable.take_profit()
        takeProfitContentLabel.text = R.string.localizable.add()
        stopLossTitleLabel.text = R.string.localizable.stop_loss()
        stopLossContentLabel.text = R.string.localizable.add()
        
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
        liquidationPriceActivityIndicator.style = .custom(diameter: 10, lineWidth: 2)
        updateDescriptions(
            marginAmount: 0,
            leverageMultiplier: leverageMultiplier,
            underlyingAsset: viewModel
        )
        
        var tags = ["direction": side.rawValue]
        tags["source"] = UserOperationAnalytics.tradeSource?.rawValue
        reporter.report(event: .tradePerpsOpenPositionStart, tags: tags)
    }
    
    override func editMarginAmount(_ textField: UITextField) {
        super.editMarginAmount(textField)
        updateDescriptions(
            marginAmount: marginAmount,
            leverageMultiplier: leverageMultiplier,
            underlyingAsset: viewModel
        )
    }
    
    override func inputAmount(withBalanceMultipliedBy balanceMultiplier: Decimal) {
        super.inputAmount(withBalanceMultipliedBy: balanceMultiplier)
        updateDescriptions(
            marginAmount: marginAmount,
            leverageMultiplier: leverageMultiplier,
            underlyingAsset: viewModel
        )
    }
    
    @IBAction func editTakeProfit(_ sender: Any) {
        guard let liquidationPrice else {
            return
        }
        let editor = EditPerpClosingConditionViewController(
            viewModel: viewModel,
            side: side,
            margin: marginAmount,
            behavior: .takeProfit,
            leverage: leverageMultiplier,
            orderState: .draft,
            liquidationPrice: liquidationPrice,
            currentAutoClosingPrice: takeProfitPrice,
        )
        editor.onSet = { [weak self] (price) in
            self?.takeProfitPrice = price
        }
        present(editor, animated: true)
    }
    
    @IBAction func editStopLoss(_ sender: Any) {
        guard let liquidationPrice else {
            return
        }
        let editor = EditPerpClosingConditionViewController(
            viewModel: viewModel,
            side: side,
            margin: marginAmount,
            behavior: .stopLoss,
            leverage: leverageMultiplier,
            orderState: .draft,
            liquidationPrice: liquidationPrice,
            currentAutoClosingPrice: stopLossPrice,
        )
        editor.onSet = { [weak self] (price) in
            self?.stopLossPrice = price
        }
        present(editor, animated: true)
    }
    
    @IBAction func presentAutoClosingManual(_ sender: Any) {
        let manual = PerpsManual.viewController(initialPage: .autoClosing)
        present(manual, animated: true)
        reporter.report(event: .tradePerpsGuide, tags: ["source": "perps_open_position_auto_closing"])
    }
    
    @IBAction func presentOrderValueManual(_ sender: Any) {
        let manual = PerpsManual.viewController(initialPage: .size)
        present(manual, animated: true)
        reporter.report(event: .tradePerpsGuide, tags: ["source": "perps_open_position_size"])
    }
    
    @IBAction func review(_ sender: ConfigurationBasedBusyButton) {
        guard let marginToken, let liquidationPrice else {
            return
        }
        reporter.report(event: .tradePerpsPreview)
        marginAmountTextField.resignFirstResponder()
        let request = OpenPerpetualOrderRequest(
            assetID: marginToken.assetID,
            marketID: viewModel.market.marketID,
            side: side,
            amount: marginAmount.formatted(
                MixinToken.transferCanonicalFormatStyle
            ),
            leverage: (leverageMultiplier as NSDecimalNumber).intValue,
            walletID: wallet.tradingWalletID,
            destination: nil,
            takeProfitPrice: takeProfitPrice?.formatted(
                viewModel.market.canonicalPriceFormatStyle
            ),
            stopLossPrice: stopLossPrice?.formatted(
                viewModel.market.canonicalPriceFormatStyle
            ),
        )
        let context = Payment.PerpsContext(
            wallet: wallet,
            viewModel: viewModel,
            operation: .open,
            side: request.side,
            leverageMultiplier: leverageMultiplier,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: takeProfitPrice,
            stopLossPrice: stopLossPrice,
            onDismissAfterSuccess: nil,
        )
        sender.isBusy = true
        RouteAPI.openPerpsOrder(orderRequest: request) { [weak self] result in
            switch result {
            case .success(let response):
                guard let url = URL(string: response.paymentURL) else {
                    if let self {
                        self.showError(description: R.string.localizable.invalid_payment_link())
                        self.reviewButton.isBusy = false
                    }
                    return
                }
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
        reporter.report(event: .customerServiceDialog, tags: ["source": "perps_open_position"])
    }
    
    private func inputCustomLeverageMultiplier() {
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
            let result = amountValidator.validate(
                amount: marginAmount,
                symbol: marginToken.symbol
            )
            switch result {
            case .valid:
                let isBalanceSufficient = marginAmount <= marginToken.decimalBalance
                liquidationPriceRequester.request(
                    amount: marginAmount,
                    leverage: (leverageMultiplier as NSDecimalNumber).intValue
                ) { [weak self] price in
                    self?.show(liquidationPrice: .valid(price: price, isBalanceSufficient: isBalanceSufficient))
                }
                show(liquidationPrice: .busy)
                showError(description: isBalanceSufficient ? nil : R.string.localizable.insufficient_balance())
            case .invalid(let reason):
                liquidationPriceRequester.cancelLastRequest()
                show(liquidationPrice: .invalid)
                showError(description: reason)
            }
        } else {
            liquidationPriceRequester.cancelLastRequest()
            show(liquidationPrice: .invalid)
            showError(description: nil)
        }
        changeSimulationLabel.text = PerpetualChangeSimulation.profit(
            side: side,
            margin: marginAmount,
            leverageMultiplier: leverageMultiplier,
            priceChangePercent: 0.01
        )
        let orderValue = marginAmount * leverageMultiplier
        orderValueContentLabel.text = CurrencyFormatter.localizedString(
            from: orderValue / underlyingAsset.decimalPrice,
            format: .precision,
            sign: .never,
            symbol: .custom(underlyingAsset.market.tokenSymbol)
        ) + " (" + CurrencyFormatter.localizedString(
            from: orderValue,
            format: .fiatMoneyPretty,
            sign: .never,
            symbol: .dollarSign,
        ) + ")"
    }
    
    private func show(liquidationPrice: LiquidationPrice) {
        switch liquidationPrice {
        case .invalid:
            self.liquidationPrice = nil
            liquidationPriceActivityIndicator.stopAnimating()
            liquidationPriceContentLabel.text = "-"
            liquidationPriceContentLabel.alpha = 1
            reviewButton.isEnabled = false
        case .busy:
            self.liquidationPrice = nil
            liquidationPriceActivityIndicator.startAnimating()
            liquidationPriceContentLabel.alpha = 0
            reviewButton.isEnabled = false
        case let .valid(price, isBalanceSufficient):
            self.liquidationPrice = price
            liquidationPriceActivityIndicator.stopAnimating()
            liquidationPriceContentLabel.text = price.formatted(
                viewModel.userDisplayPriceFormatStyle
            )
            liquidationPriceContentLabel.alpha = 1
            reviewButton.isEnabled = isBalanceSufficient
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
            reporter.report(event: .tradePerpsLeverageSelect, tags: ["leverage": "custom_tab"])
            inputCustomLeverageMultiplier()
            return false
        default:
            return true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        switch multipliers[indexPath.item] {
        case .custom:
            reporter.report(event: .tradePerpsLeverageSelect, tags: ["leverage": "custom_tab"])
            inputCustomLeverageMultiplier()
        default:
            break
        }
        return false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        marginAmountTextField.resignFirstResponder()
        switch multipliers[indexPath.item] {
        case .fixed(let leverage):
            reporter.report(event: .tradePerpsLeverageSelect, tags: ["leverage": "\(leverage)x"])
            inputLeverageMultiplier(value: leverage)
        case .max:
            reporter.report(event: .tradePerpsLeverageSelect, tags: ["leverage": "max"])
            inputLeverageMultiplier(value: viewModel.maxLeverageMultiplier)
        case .custom:
            break
        }
    }
    
}

extension OpenPerpetualPositionViewController: UITextFieldDelegate {
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        reporter.report(event: .tradePerpsLeverageSelect, tags: ["leverage": "custom_input"])
        inputCustomLeverageMultiplier()
        return false
    }
    
}

extension OpenPerpetualPositionViewController {
    
    private enum LiquidationPrice {
        case invalid
        case busy
        case valid(price: Decimal, isBalanceSufficient: Bool)
    }
    
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
    
}
