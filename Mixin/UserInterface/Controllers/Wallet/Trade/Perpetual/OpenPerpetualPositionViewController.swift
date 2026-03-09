import UIKit
import MixinServices

final class OpenPerpetualPositionViewController: UIViewController {
    
    private enum Multiplier {
        case fixed(Decimal)
        case max
        case custom(Decimal)
    }
    
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
    
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var reviewButton: UIButton!
    
    private let wallet: Wallet
    private let side: PerpetualOrderSide
    private let viewModel: PerpetualMarketViewModel
    private let multipliers: [Multiplier]
    private let cellReuseIdentifier = "l"
    
    private weak var contentSizeObserver: NSKeyValueObservation?
    
    private var marginAmount: Decimal = 0
    
    private var marginTokens: [MixinTokenItem] = []
    private var marginToken: MixinTokenItem? {
        didSet {
            guard let token = marginToken else {
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
            marginTokenNameLabel.text = token.name
        }
    }
    
    private var multiplier: Decimal
    
    init(
        wallet: Wallet,
        side: PerpetualOrderSide,
        viewModel: PerpetualMarketViewModel,
    ) {
        self.wallet = wallet
        self.side = side
        self.viewModel = viewModel
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
        self.multiplier = viewModel.market.leverage > 10 ? 10 : 2
        let nib = R.nib.openPerpetualPositionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Open Position"
        
        tokenIconView.setIcon(tokenIconURL: viewModel.iconURL)
        switch side {
        case .long:
            titleLabel.text = "Long \(viewModel.symbol)"
        case .short:
            titleLabel.text = "Short \(viewModel.symbol)"
        }
        priceLabel.text = "Current price: \(viewModel.price)"
        
        marginView.layer.cornerRadius = 8
        marginView.layer.masksToBounds = true
        marginContentStackView.setCustomSpacing(3, after: marginTokenSelectorStackView)
        marginTitleLabel.text = R.string.localizable.amount()
        marginTokenBalanceButton.titleLabel?.adjustsFontForContentSizeCategory = true
        marginLoadingView.startAnimating()
        
        leverageView.layer.cornerRadius = 8
        leverageView.layer.masksToBounds = true
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
        leverageMultipliersCollectionView.reloadData()
        inputLeverageMultiplier(value: multiplier)
        updateDescriptions(
            marginAmount: 0,
            leverageMultiplier: multiplier,
            underlyingAsset: viewModel
        )
        
        reviewButton.configuration?.title = R.string.localizable.review()
        reviewButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
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
            leverageMultiplier: multiplier,
            underlyingAsset: viewModel
        )
        reviewButton.isEnabled = amount > 0 // TODO: check with max/min
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
        guard let token = marginToken else {
            return
        }
        marginAmountTextField.text = CurrencyFormatter.localizedString(
            from: token.decimalBalance,
            format: .precision,
            sign: .never,
        )
    }
    
    @IBAction func review(_ sender: ConfigurationBasedBusyButton) {
        guard let marginToken else {
            return
        }
        let request = OpenPerpetualOrderRequest(
            assetID: marginToken.assetID,
            productID: viewModel.market.marketID,
            side: side,
            amount: TokenAmountFormatter.string(from: marginAmount * multiplier),
            leverage: (multiplier as NSDecimalNumber).intValue,
            walletID: wallet.tradeOrderWalletID,
            destination: nil
        )
        sender.isBusy = true
        RouteAPI.openPerpsOrder(
            orderRequest: request
        ) { [weak sender, wallet, viewModel, multiplier] result in
            switch result {
            case .success(let response):
                guard let payURL = response.payURL, let url = URL(string: payURL) else {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.invalid_payment_link())
                    return
                }
                let context = Payment.PerpsContext(
                    wallet: wallet,
                    viewModel: viewModel,
                    side: request.side,
                    leverageMultiplier: multiplier
                )
                let source: UrlWindow.Source = .perps(context: context) { description in
                    if let description {
                        showAutoHiddenHud(style: .error, text: description)
                    }
                    sender?.isBusy = false
                }
                _ = UrlWindow.checkUrl(url: url, from: source)
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                sender?.isBusy = false
            }
        }
    }
    
    private func reloadMarginTokens() {
        RouteAPI.acceptedPerpsOrderAssets(queue: .global()) { result in
            switch result {
            case .success(let assetIDs):
                let tokens = TokenDAO.shared.tokenItems(with: assetIDs)
                    .sorted { one, another in
                        one.decimalBalance >= another.decimalBalance
                    }
                DispatchQueue.main.async {
                    self.marginTokens = tokens
                    self.marginToken = tokens.first
                    self.marginTokenSelectorStackView.alpha = 1
                    self.marginTokenFooterStackView.alpha = 1
                    self.marginLoadingView.stopAnimating()
                }
            case .failure(let error):
                break
            }
        }
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
        self.multiplier = value
        marginAmountTextField.resignFirstResponder()
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
    }
    
    private func updateDescriptions(
        marginAmount: Decimal,
        leverageMultiplier: Decimal,
        underlyingAsset: PerpetualMarketViewModel
    ) {
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
                format: .precision,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            liquidationPriceContentLabel.text = "-"
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
            "Custom"
        }
        return cell
    }
    
}

extension OpenPerpetualPositionViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch multipliers[indexPath.item] {
        case .custom:
            let input = LeverageMultiplierInputViewController(
                side: side,
                maxMultiplier: viewModel.maxLeverageMultiplier,
                marginAmount: marginAmount,
                currentMultiplier: multiplier
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
            let input = LeverageMultiplierInputViewController(
                side: side,
                maxMultiplier: viewModel.maxLeverageMultiplier,
                marginAmount: marginAmount,
                currentMultiplier: multiplier
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
    
}
