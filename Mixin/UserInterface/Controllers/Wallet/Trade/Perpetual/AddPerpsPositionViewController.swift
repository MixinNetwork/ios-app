import UIKit
import MixinServices

final class AddPerpsPositionViewController: PerpsMarginInputViewController {
    
    @IBOutlet weak var titleView: EditPerpsPositionTitleView!
    
    @IBOutlet weak var addSizeTitleLabel: UILabel!
    @IBOutlet weak var addSizeContentLabel: UILabel!
    @IBOutlet weak var totalSizeTitleLabel: UILabel!
    @IBOutlet weak var totalSizeContentLabel: UILabel!
    @IBOutlet weak var liquidationPriceTitleLabel: UILabel!
    @IBOutlet weak var liquidationPriceContentLabel: UILabel!
    
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    
    @IBOutlet weak var actionWrapperView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var addButton: UIButton!
    
    private let wallet: Wallet
    private let marketViewModel: PerpetualMarketViewModel
    private let positionViewModel: PerpetualPositionViewModel
    private let openedMargin: Decimal
    private let leverageMultiplier: Decimal
    private let amountValidator: AmountValidator
    
    private var isAdding = false {
        didSet {
            if isAdding {
                cancelButton.isEnabled = false
                addButton.isEnabled = false
                addButton.configuration?.title = R.string.localizable.adding_position()
                titleView.closeButton.isEnabled = false
            } else {
                cancelButton.isEnabled = true
                addButton.isEnabled = true
                addButton.configuration?.title = R.string.localizable.add_position()
                titleView.closeButton.isEnabled = true
            }
        }
    }
    
    init(
        wallet: Wallet,
        marketViewModel: PerpetualMarketViewModel,
        positionViewModel: PerpetualPositionViewModel,
        openedMargin: Decimal,
    ) {
        self.wallet = wallet
        self.marketViewModel = marketViewModel
        self.positionViewModel = positionViewModel
        self.openedMargin = openedMargin
        self.leverageMultiplier = Decimal(positionViewModel.leverageMultiplier)
        self.amountValidator = AmountValidator(market: marketViewModel.market)
        let nib = R.nib.addPerpsPositionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presentationController?.delegate = self
        
        titleView.iconView.setIcon(tokenIconURL: marketViewModel.iconURL)
        titleView.titleLabel.text = R.string.localizable.add_position_title(
            positionViewModel.side.localizedName,
            marketViewModel.market.tokenSymbol
        )
        titleView.subtitleLabel.attributedText = {
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
            return text
        }()
        titleView.closeButton.addTarget(
            self,
            action: #selector(cancel(_:)),
            for: .touchUpInside
        )
        
        let infoLabels: [UILabel] = [
            addSizeTitleLabel,
            addSizeContentLabel,
            totalSizeTitleLabel,
            totalSizeContentLabel,
            liquidationPriceTitleLabel,
            liquidationPriceContentLabel,
        ]
        for label in infoLabels {
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
        addSizeTitleLabel.text = R.string.localizable.add_position_add_size()
        totalSizeTitleLabel.text = R.string.localizable.add_position_total_size()
        liquidationPriceTitleLabel.text = R.string.localizable.liquidation_price()
        updateDescriptions(marginAmount: 0)
        
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
            config.title = R.string.localizable.add_position()
            addButton.configuration = config
        }
        addButton.titleLabel?.adjustsFontForContentSizeCategory = true
        marginAmountTextField.becomeFirstResponder()
    }
    
    override func editMarginAmount(_ textField: UITextField) {
        super.editMarginAmount(textField)
        updateDescriptions(marginAmount: marginAmount)
    }
    
    override func inputAmount(withBalanceMultipliedBy balanceMultiplier: Decimal) {
        super.inputAmount(withBalanceMultipliedBy: balanceMultiplier)
        updateDescriptions(marginAmount: marginAmount)
    }
    
    @IBAction func introduceSize(_ sender: Any) {
        let manual = PerpsManual.viewController(initialPage: .size)
        present(manual, animated: true)
        reporter.report(event: .tradePerpsGuide, tags: ["source": "perps_add_position_size"])
    }
    
    @IBAction func introduceLiquidationPrice(_ sender: Any) {
        let manual = PerpsManual.viewController(initialPage: .liquidation)
        present(manual, animated: true)
        reporter.report(event: .tradePerpsGuide, tags: ["source": "perps_add_position_liquidation"])
    }
    
    @IBAction func cancel(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @IBAction func add(_ sender: Any) {
        guard let assetID = marginToken?.assetID else {
            return
        }
        isAdding = true
        showError(description: nil)
        let amount = marginAmount.formatted(
            MixinToken.transferCanonicalFormatStyle
        )
        let context = Payment.PerpsContext(
            wallet: wallet,
            viewModel: marketViewModel,
            operation: .increase,
            side: positionViewModel.side,
            leverageMultiplier: leverageMultiplier,
            takeProfitPrice: nil,
            stopLossPrice: nil,
            onDismissAfterSuccess: { [weak self] in
                self?.presentingViewController?.dismiss(animated: true)
            },
        )
        RouteAPI.increasePerpsPosition(
            positionID: positionViewModel.positionID,
            assetID: assetID,
            amount: amount,
            destination: nil
        ) { [weak self] result in
            switch result {
            case let .success(response):
                guard let url = URL(string: response.paymentURL) else {
                    if let self {
                        self.showError(description: R.string.localizable.invalid_payment_link())
                        self.isAdding = false
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
                    self.isAdding = false
                }
                _ = UrlWindow.checkUrl(url: url, from: source)
            case let .failure(error):
                guard let self else {
                    return
                }
                self.showError(description: error.localizedDescription)
                self.isAdding = false
            }
        }
    }
    
    private func updateDescriptions(marginAmount: Decimal) {
        let addingExposure = marginAmount * leverageMultiplier
        addSizeContentLabel.text = CurrencyFormatter.localizedString(
            from: addingExposure / marketViewModel.decimalPrice,
            format: .precision,
            sign: .never,
            symbol: .custom(marketViewModel.market.tokenSymbol)
        ) + " (" + CurrencyFormatter.localizedString(
            from: addingExposure,
            format: .fiatMoneyPretty,
            sign: .never,
            symbol: .dollarSign
        ) + ")"
        totalSizeContentLabel.text = CurrencyFormatter.localizedString(
            from: positionViewModel.decimalQuantity + addingExposure / marketViewModel.decimalPrice,
            format: .precision,
            sign: .never,
            symbol: .custom(marketViewModel.market.tokenSymbol)
        ) + " (" + CurrencyFormatter.localizedString(
            from: (openedMargin + marginAmount) * leverageMultiplier,
            format: .fiatMoneyPretty,
            sign: .never,
            symbol: .dollarSign
        ) + ")"
        if marginAmount > 0 {
            let liquidationPrice = switch positionViewModel.side {
            case .long:
                marketViewModel.decimalPrice * (1 - 1 / leverageMultiplier)
            case .short:
                marketViewModel.decimalPrice * (1 + 1 / leverageMultiplier)
            }
            liquidationPriceContentLabel.text = liquidationPrice.formatted(
                marketViewModel.userDisplayPriceFormatStyle
            )
        } else {
            liquidationPriceContentLabel.text = "-"
        }
        if marginAmount != 0, let marginToken {
            if marginAmount > marginToken.decimalBalance {
                showError(description: R.string.localizable.insufficient_balance())
                addButton.isEnabled = false
            } else {
                let result = amountValidator.validate(
                    amount: marginAmount,
                    symbol: marginToken.symbol
                )
                switch result {
                case .valid:
                    showError(description: nil)
                    addButton.isEnabled = true
                case .invalid(let reason):
                    showError(description: reason)
                    addButton.isEnabled = false
                }
            }
        } else {
            showError(description: nil)
            addButton.isEnabled = false
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

extension AddPerpsPositionViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        false
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        
    }
    
}
