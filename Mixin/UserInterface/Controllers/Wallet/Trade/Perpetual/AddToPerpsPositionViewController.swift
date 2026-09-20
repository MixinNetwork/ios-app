import UIKit
import MixinServices

final class AddToPerpsPositionViewController: PerpsMarginInputViewController {
    
    @IBOutlet weak var titleView: EditPerpsPositionTitleView!
    
    @IBOutlet weak var targetTitleLabel: UILabel!
    @IBOutlet weak var targetContentLabel: UILabel!
    @IBOutlet weak var introduceTargetIconView: UIImageView!
    @IBOutlet weak var introduceTargetButton: UIButton!
    @IBOutlet weak var liquidationPriceTitleLabel: UILabel!
    @IBOutlet weak var liquidationPriceContentLabel: UILabel!
    @IBOutlet weak var liquidationPriceActivityIndicator: ActivityIndicatorView!
    
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    
    @IBOutlet weak var actionWrapperView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var addButton: UIButton!
    
    override var marginToken: MixinTokenItem? {
        didSet {
            updateDescriptions(
                marginAmount: marginAmount,
                requestLiquidationPrice: true
            )
        }
    }
    
    private let wallet: Wallet
    private let target: PerpPositionAdjustmentTarget
    private let presentMarketViewOnSuccess: Bool
    private let liquidationPriceRequester: EditPerpsPositionLiquidationPriceRequester
    
    private var marketViewModel: PerpetualMarketViewModel
    private var positionViewModel: PerpetualPositionViewModel
    private var leverageMultiplier: Decimal
    private var liquidationPriceBeforeAdding: String
    private var liquidationPriceAfterAdding: Decimal?
    
    private var isAdding = false {
        didSet {
            if isAdding {
                marginView.isUserInteractionEnabled = false
                cancelButton.isEnabled = false
                addButton.isEnabled = false
                addButton.configuration?.title = switch target {
                case .margin:
                    R.string.localizable.perps_adding_margin()
                case .position:
                    R.string.localizable.adding_position()
                }
                titleView.closeButton.isEnabled = false
            } else {
                marginView.isUserInteractionEnabled = true
                cancelButton.isEnabled = true
                addButton.isEnabled = true
                addButton.configuration?.title = switch target {
                case .margin:
                    R.string.localizable.perps_add_margin()
                case .position:
                    R.string.localizable.add_position()
                }
                titleView.closeButton.isEnabled = true
            }
        }
    }
    
    init(
        wallet: Wallet,
        adding target: PerpPositionAdjustmentTarget,
        marketViewModel: PerpetualMarketViewModel,
        positionViewModel: PerpetualPositionViewModel,
        leaderPosition: TradeURL.LeaderPosition?,
        presentMarketViewOnSuccess: Bool,
    ) {
        self.wallet = wallet
        self.target = target
        self.marketViewModel = marketViewModel
        self.positionViewModel = positionViewModel
        self.liquidationPriceBeforeAdding = positionViewModel.decimalLiquidationPrice?.formatted(
            marketViewModel.userDisplayPriceFormatStyle
        ) ?? "-"
        self.leverageMultiplier = Decimal(positionViewModel.leverageMultiplier)
        self.presentMarketViewOnSuccess = presentMarketViewOnSuccess
        self.liquidationPriceRequester = switch target {
        case .position:
            EditPerpsPositionLiquidationPriceRequester(
                positionID: positionViewModel.positionID,
                action: .increasePosition,
            )
        case .margin:
            EditPerpsPositionLiquidationPriceRequester(
                positionID: positionViewModel.positionID,
                action: .increaseMargin,
            )
        }
        let nib = R.nib.addToPerpsPositionView
        super.init(leaderPosition: leaderPosition, nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presentationController?.delegate = self
        
        var tags: [String: String] = [:]
        tags["source"] = UserOperationAnalytics.tradeSource?.rawValue
        
        titleView.iconView.setIcon(tokenIconURL: marketViewModel.iconURL)
        switch target {
        case .position:
            reporter.report(event: .tradePerpsAddPositionStart, tags: tags)
            titleView.titleLabel.text = R.string.localizable.perps_add_position_title(
                positionViewModel.side.localizedName,
                marketViewModel.market.tokenSymbol
            )
            targetTitleLabel.text = R.string.localizable.position_size()
            introduceTargetIconView.isHidden = false
            introduceTargetButton.isHidden = false
        case .margin:
            reporter.report(event: .tradePerpsAddMarginStart, tags: tags)
            titleView.titleLabel.text = R.string.localizable.perps_add_margin_title(
                positionViewModel.side.localizedName,
                marketViewModel.market.tokenSymbol
            )
            targetTitleLabel.text = R.string.localizable.margin()
            introduceTargetIconView.isHidden = true
            introduceTargetButton.isHidden = true
        }
        updateSubtitle()
        titleView.closeButton.addTarget(
            self,
            action: #selector(cancel(_:)),
            for: .touchUpInside
        )
        
        let infoLabels: [UILabel] = [
            targetTitleLabel,
            targetContentLabel,
            liquidationPriceTitleLabel,
            liquidationPriceContentLabel,
        ]
        for label in infoLabels {
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
        liquidationPriceTitleLabel.text = R.string.localizable.liquidation_price()
        liquidationPriceActivityIndicator.style = .custom(diameter: 10, lineWidth: 2)
        updateDescriptions(marginAmount: marginAmount, requestLiquidationPrice: marginAmount != 0)
        
        actionWrapperView.snp.makeConstraints { make in
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }
        if var config = cancelButton.configuration {
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.preferredFont(forTextStyle: .callout)
                return outgoing
            }
            config.title = R.string.localizable.cancel()
            cancelButton.configuration = config
        }
        cancelButton.titleLabel?.adjustsFontForContentSizeCategory = true
        if var config = addButton.configuration {
            config.baseBackgroundColor = MarketColor.rising.uiColor
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.preferredFont(forTextStyle: .callout)
                return outgoing
            }
            config.title = switch target {
            case .margin:
                R.string.localizable.perps_add_margin()
            case .position:
                R.string.localizable.add_position()
            }
            addButton.configuration = config
        }
        addButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadMarket(_:)),
            name: PerpsMarketDAO.marketsDidUpdateNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadPosition),
            name: PerpsPositionDAO.perpsPositionDidChangeNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil,
        )
        marginAmountTextField.becomeFirstResponder()
    }
    
    override func editMarginAmount(_ textField: UITextField) {
        super.editMarginAmount(textField)
        updateDescriptions(marginAmount: marginAmount, requestLiquidationPrice: true)
    }
    
    override func inputAmount(withBalanceMultipliedBy balanceMultiplier: Decimal) {
        super.inputAmount(withBalanceMultipliedBy: balanceMultiplier)
        updateDescriptions(marginAmount: marginAmount, requestLiquidationPrice: true)
    }
    
    override func inputTokenBalance(_ sender: Any) {
        inputAmount(withBalanceMultipliedBy: 1)
    }
    
    override func reportMarginTokenSelection(tags: [String : String]) {
        switch target {
        case .position:
            reporter.report(event: .tradePerpsAddPositionTokenSelect, tags: tags)
        case .margin:
            reporter.report(event: .tradePerpsAddMarginTokenSelect, tags: tags)
        }
    }
    
    @IBAction func introduceTarget(_ sender: Any) {
        switch target {
        case .position:
            let manual = PerpsManual.viewController(initialPage: .size)
            present(manual, animated: true)
            reporter.report(event: .tradePerpsGuide, tags: ["source": "perps_add_position_size"])
        case .margin:
            let manual = PerpsManual.viewController(initialPage: .liquidation)
            present(manual, animated: true)
            reporter.report(event: .tradePerpsGuide, tags: ["source": "perps_add_margin_liquidation"])
        }
    }
    
    @IBAction func introduceLiquidationPrice(_ sender: Any) {
        let manual = PerpsManual.viewController(initialPage: .liquidation)
        present(manual, animated: true)
        switch target {
        case .position:
            reporter.report(event: .tradePerpsGuide, tags: ["source": "perps_add_position_liquidation"])
        case .margin:
            reporter.report(event: .tradePerpsGuide, tags: ["source": "perps_add_margin_liquidation"])
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        switch target {
        case .position:
            reporter.report(event: .tradePerpsAddPositionCancel)
        case .margin:
            reporter.report(event: .tradePerpsAddMarginCancel)
        }
    }
    
    @IBAction func add(_ sender: Any) {
        guard
            let assetID = marginToken?.assetID,
            let liquidationPrice = liquidationPriceAfterAdding
        else {
            return
        }
        switch target {
        case .position:
            reporter.report(event: .tradePerpsAddPositionPreview)
        case .margin:
            reporter.report(event: .tradePerpsAddMarginPreview)
        }
        isAdding = true
        showError(description: nil)
        let amount = marginAmount.formatted(
            MixinToken.transferCanonicalFormatStyle
        )
        let operation: Payment.PerpsContext.Operation = switch target {
        case .position:
                .increasePosition(
                    quantityBefore: positionViewModel.decimalQuantity,
                    marginBefore: positionViewModel.decimalMargin,
                )
        case .margin:
                .increaseMargin(marginBefore: positionViewModel.decimalMargin)
        }
        let context = Payment.PerpsContext(
            wallet: wallet,
            viewModel: marketViewModel,
            operation: operation,
            side: positionViewModel.side,
            leverageMultiplier: leverageMultiplier,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: nil,
            stopLossPrice: nil,
            presentMarketViewOnSuccess: presentMarketViewOnSuccess,
            onDismissAfterSuccess: { [weak self] in
                self?.presentingViewController?.dismiss(animated: true)
            },
        )
        switch target {
        case .position:
            RouteAPI.increasePerpsPosition(
                positionID: positionViewModel.positionID,
                assetID: assetID,
                amount: amount,
                destination: nil,
                leaderPositionID: leaderPosition?.id
            ) { [weak self] response in
                self?.handlePayment(context: context, response: response)
            }
        case .margin:
            RouteAPI.increasePerpsMargin(
                positionID: positionViewModel.positionID,
                assetID: assetID,
                amount: amount,
                destination: nil
            ) { [weak self] response in
                self?.handlePayment(context: context, response: response)
            }
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        guard viewIfLoaded?.window != nil, presentedViewController == nil else {
            return
        }
        marginAmountTextField.becomeFirstResponder()
    }
    
    @objc private func reloadMarket(_ notification: Notification) {
        guard
            let market = notification.userInfo?[PerpsMarketDAO.UserInfoKey.market] as? PerpetualMarket,
            market.marketID == marketViewModel.market.marketID
        else {
            return
        }
        let viewModel = PerpetualMarketViewModel(market: market)
        marketViewModel = viewModel
        updateSubtitle()
        updateDescriptions(marginAmount: marginAmount, requestLiquidationPrice: false)
    }
    
    @objc private func reloadPosition() {
        let positionID = positionViewModel.positionID
        DispatchQueue.global().async { [weak self, wallet] in
            guard let position = PerpsPositionDAO.shared.position(positionID: positionID) else {
                return
            }
            let viewModel = PerpetualPositionViewModel(wallet: wallet, position: position)
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.positionViewModel = viewModel
                self.liquidationPriceBeforeAdding = viewModel.decimalLiquidationPrice?.formatted(
                    self.marketViewModel.userDisplayPriceFormatStyle
                ) ?? "-"
                self.leverageMultiplier = Decimal(viewModel.leverageMultiplier)
                self.updateSubtitle()
                self.updateDescriptions(marginAmount: self.marginAmount, requestLiquidationPrice: false)
            }
        }
    }
    
    private func updateSubtitle() {
        let currentPrice = marketViewModel.price
        let text = NSMutableAttributedString(
            string: R.string.localizable.auto_close_subtitle_after_open(
                positionViewModel.entryPrice,
                currentPrice
            ),
            attributes: [.foregroundColor: R.color.text_quaternary()!]
        )
        if let range = text.string.range(of: positionViewModel.entryPrice) {
            text.setAttributes(
                [.foregroundColor: R.color.text_tertiary()!],
                range: NSRange(range, in: text.string)
            )
        }
        if let range = text.string.range(of: currentPrice, options: .backwards) {
            text.setAttributes(
                [.foregroundColor: R.color.text_tertiary()!],
                range: NSRange(range, in: text.string)
            )
        }
        titleView.subtitleLabel.attributedText = text
    }
    
    private func updateDescriptions(
        marginAmount: Decimal,
        requestLiquidationPrice: Bool,
    ) {
        switch target {
        case .position:
            let before = CurrencyFormatter.localizedString(
                from: positionViewModel.decimalQuantity,
                format: .precision,
                sign: .never,
                symbol: .custom(marketViewModel.market.tokenSymbol)
            )
            if marginAmount != 0, marginToken != nil {
                let afterQuantity = positionViewModel.decimalQuantity +
                    marginAmount * leverageMultiplier / marketViewModel.decimalPrice
                let after = CurrencyFormatter.localizedString(
                    from: afterQuantity,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(marketViewModel.market.tokenSymbol)
                ) + " (" + CurrencyFormatter.localizedString(
                    from: afterQuantity * marketViewModel.decimalPrice,
                    format: .fiatMoneyPretty,
                    sign: .never,
                    symbol: .dollarSign
                ) + ")"
                targetContentLabel.text = PerpPositionAdjustment.change(from: before, to: after)
            } else {
                let value = CurrencyFormatter.localizedString(
                    from: positionViewModel.decimalQuantity * marketViewModel.decimalPrice,
                    format: .fiatMoneyPretty,
                    sign: .never,
                    symbol: .dollarSign
                )
                targetContentLabel.text = before + " (" + value + ")"
            }
        case .margin:
            let before = CurrencyFormatter.localizedString(
                from: positionViewModel.decimalMargin,
                format: .fiatMoneyPretty,
                sign: .never,
                symbol: .dollarSign
            )
            if marginAmount > 0, marginToken != nil {
                let after = CurrencyFormatter.localizedString(
                    from:  positionViewModel.decimalMargin + marginAmount,
                    format: .fiatMoneyPretty,
                    sign: .never,
                    symbol: .dollarSign
                )
                targetContentLabel.text = PerpPositionAdjustment.change(from: before, to: after)
            } else {
                targetContentLabel.text = before
            }
        }
        
        if requestLiquidationPrice {
            if marginAmount != 0, let marginToken {
                let isBalanceSufficient = marginAmount <= marginToken.decimalBalance
                liquidationPriceRequester.request(
                    amount: marginAmount
                ) { [weak self] price in
                    self?.show(liquidationPrice: .valid(price: price, isBalanceSufficient: isBalanceSufficient))
                } onFailure: { [weak self] error in
                    guard let self else {
                        return
                    }
                    self.show(liquidationPrice: .invalid)
                    self.showError(description: error.localizedDescription)
                }
                show(liquidationPrice: .busy)
                showError(description: isBalanceSufficient ? nil : R.string.localizable.insufficient_balance())
            } else {
                liquidationPriceRequester.cancelLastRequest()
                show(liquidationPrice: .invalid)
                showError(description: nil)
            }
        }
    }
    
    private func show(liquidationPrice: LiquidationPrice) {
        switch liquidationPrice {
        case .invalid:
            self.liquidationPriceAfterAdding = nil
            liquidationPriceActivityIndicator.stopAnimating()
            liquidationPriceContentLabel.text = liquidationPriceBeforeAdding
            liquidationPriceContentLabel.alpha = 1
            addButton.isEnabled = false
        case .busy:
            self.liquidationPriceAfterAdding = nil
            liquidationPriceActivityIndicator.startAnimating()
            liquidationPriceContentLabel.alpha = 0
            addButton.isEnabled = false
        case let .valid(price, isBalanceSufficient):
            self.liquidationPriceAfterAdding = price
            liquidationPriceActivityIndicator.stopAnimating()
            let after = price.formatted(
                marketViewModel.userDisplayPriceFormatStyle
            )
            liquidationPriceContentLabel.text = PerpPositionAdjustment.change(
                from: liquidationPriceBeforeAdding,
                to: after,
            )
            liquidationPriceContentLabel.alpha = 1
            addButton.isEnabled = isBalanceSufficient && !isAdding
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
    
    private func handlePayment(
        context: Payment.PerpsContext,
        response: MixinAPI.Result<OpenPerpetualOrderResponse>,
    ) {
        switch response {
        case let .success(response):
            guard let url = URL(string: response.paymentURL) else {
                self.showError(description: R.string.localizable.invalid_payment_link())
                self.isAdding = false
                return
            }
            let source: UrlWindow.Source = .perps(context: context) { [weak self] description in
                guard let self else {
                    return
                }
                if let description {
                    self.showError(description: description)
                }
                self.isAdding = false
            }
            _ = UrlWindow.checkUrl(url: url, from: source)
        case let .failure(error):
            self.showError(description: error.localizedDescription)
            self.isAdding = false
        }
    }
    
}

extension AddToPerpsPositionViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        false
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        
    }
    
}

extension AddToPerpsPositionViewController {
    
    private enum LiquidationPrice {
        case invalid
        case busy
        case valid(price: Decimal, isBalanceSufficient: Bool)
    }
    
}
