import UIKit
import LinkPresentation
import MixinServices

final class ShareMarketContentViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    
    @IBOutlet weak var coverView: UIView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var tagLabel: InsetLabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var changeLabel: InsetLabel!
    @IBOutlet weak var tokenIconView: PlainTokenIconView!
    @IBOutlet weak var chartWrapperView: UIView!
    
    @IBOutlet weak var obiView: ShareObiView!
    
    @IBOutlet weak var contentWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentHeightConstraint: NSLayoutConstraint!
    
    private enum Source {
        case spot(Market, [ChartView.Point])
        case perpetual(PerpetualMarketViewModel, [PerpetualCandleViewModel], currentPrice: Decimal)
    }
    
    private let source: Source
    private let symbol: String
    private let localizedPrice: String
    private let reportingType: String
    private let obiContent: ShareObiView.Content
    private let contentMargin: CGFloat = 28
    
    init(
        market: Market,
        points: [ChartView.Point],
        rebatingCode: Referral.RebatingCode?,
    ) {
        self.source = .spot(market, points)
        self.symbol = market.symbol
        self.localizedPrice = market.localizedPrice
        self.reportingType = "spot"
        self.obiContent = if let rebatingCode {
            .referral(rebatingCode)
        } else {
            .installMixin
        }
        let nib = R.nib.shareMarketContentView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    init(
        viewModel: PerpetualMarketViewModel,
        candles: [PerpetualCandleViewModel],
        rebatingCode: Referral.RebatingCode?,
    ) {
        let priceDisplay = PerpetualMarketViewModel.PriceDisplay(
            rawValue: AppGroupUserDefaults.Wallet.perpsPriceDisplay
        ) ?? .lastPrice
        let currentPrice: Decimal
        switch priceDisplay {
        case .lastPrice:
            currentPrice = viewModel.decimalLastPrice
            self.localizedPrice = viewModel.localizedLastPrice
        case .markPrice:
            currentPrice = viewModel.market.decimalMarkPrice
            self.localizedPrice = viewModel.market.localizedMarkPrice
        }
        self.source = .perpetual(viewModel, candles, currentPrice: currentPrice)
        self.symbol = viewModel.market.displaySymbol
        self.reportingType = "perps"
        self.obiContent = if let rebatingCode {
            .referral(rebatingCode)
        } else {
            .installMixin
        }
        let nib = R.nib.shareMarketContentView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let heightGuide = UILayoutGuide()
        view.addLayoutGuide(heightGuide)
        heightGuide.snp.makeConstraints { make in
            make.width.height.centerX.centerY.equalToSuperview().priority(.low)
            make.width.equalTo(heightGuide.snp.height)
                .multipliedBy(
                    contentWidthConstraint.constant / contentHeightConstraint.constant
                )
                .offset(2 * contentMargin)
        }
        
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        
        symbolLabel.font = .systemFont(
            ofSize: 14,
            weight: .accessiblityBoldTextCounterWeight(.regular)
        )
        symbolLabel.text = symbol
        
        tagLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        tagLabel.layer.masksToBounds = true
        tagLabel.layer.cornerRadius = 4
        
        priceLabel.font = .systemFont(
            ofSize: 22,
            weight: .accessiblityBoldTextCounterWeight(.medium)
        )
        
        changeLabel.contentInset = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
        changeLabel.layer.masksToBounds = true
        changeLabel.layer.cornerRadius = 4
        changeLabel.font = .systemFont(
            ofSize: 12,
            weight: .accessiblityBoldTextCounterWeight(.medium)
        )
        
        switch source {
        case let .spot(market, points):
            tagLabel.font = .systemFont(
                ofSize: 12,
                weight: .accessiblityBoldTextCounterWeight(.medium)
            )
            tagLabel.text = market.numberedRank
            tagLabel.isHidden = tagLabel.text == nil
            priceLabel.text = localizedPrice
            let chartView = ChartView()
            chartView.isUserInteractionEnabled = false
            chartWrapperView.addSubview(chartView)
            chartView.snp.makeEdgesEqualToSuperview()
            view.layoutIfNeeded()
            chartView.annotateExtremums = true
            chartView.minPointPosition = 123 / 168
            chartView.maxPointPosition = 21 / 168
            chartView.delegate = self
            tokenIconView.setIcon(market: market)
            if points.count >= 2 {
                let base = points[0]
                let now = points[points.count - 1]
                let change = (now.value - base.value) / base.value
                if let changePercentage = NumberFormatter.percentage.string(decimal: change) {
                    changeLabel.text = changePercentage
                    changeLabel.alpha = 1
                } else {
                    changeLabel.alpha = 0
                }
                changeLabel.backgroundColor = MarketColor.byValue(change).uiColor
                chartView.points = points
            } else {
                changeLabel.alpha = 0
                let unavailableView = PriceDataUnavailableView()
                chartWrapperView.addSubview(unavailableView)
                unavailableView.snp.makeEdgesEqualToSuperview()
            }
        case let .perpetual(viewModel, candles, currentPrice):
            tagLabel.font = .condensed(size: 12)
            tagLabel.text = viewModel.leverage
            tagLabel.backgroundColor = R.color.background_quaternary()
            tagLabel.contentInset = UIEdgeInsets(top: 2, left: 3, bottom: 0, right: 3)
            priceLabel.text = localizedPrice
            changeLabel.text = viewModel.change
            changeLabel.backgroundColor = viewModel.changeColor.uiColor
            tokenIconView.setIcon(tokenIconURL: viewModel.iconURL)
            if candles.isEmpty {
                let unavailableView = PriceDataUnavailableView()
                chartWrapperView.addSubview(unavailableView)
                unavailableView.snp.makeEdgesEqualToSuperview()
            } else {
                let chartView = CandlestickChartView()
                chartView.isUserInteractionEnabled = false
                chartWrapperView.addSubview(chartView)
                chartView.snp.makeEdgesEqualToSuperview()
                view.layoutIfNeeded()
                chartView.currentPrice = currentPrice
                chartView.setCandles(
                    candles,
                    priceFormatStyle: viewModel.userDisplayPriceFormatStyle,
                    scrollsToLast: true
                )
            }
        }
        
        obiView.load(gradient: true, content: obiContent)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let scaleX = (view.bounds.width - 2 * contentMargin) / contentWidthConstraint.constant
        let scaleY = view.bounds.height / contentHeightConstraint.constant
        let scale = min(scaleX, scaleY)
        contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
    
}

extension ShareMarketContentViewController: ModernShareContentViewController {
    
    func shareAsActivity() {
        guard let presentingViewController else {
            return
        }
        reporter.report(
            event: .marketShare,
            tags: ["type": reportingType, "target": "share_image"]
        )
        let image = ShareCardImage.render(
            view: contentView,
            padsToSquare: false
        )
        let item = ActivityItem(
            title: symbol + " " + R.string.localizable.market(),
            image: image
        )
        let activity = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        presentingViewController.dismiss(animated: true) {
            presentingViewController.present(activity, animated: true)
        }
    }
    
    func copyLink() {
        reporter.report(
            event: .marketShare,
            tags: ["type": reportingType, "target": "copy_link"]
        )
        switch obiContent {
        case .referral:
            UIPasteboard.general.string = obiContent.url
        case .installMixin:
            var link: String
            let referralParameter: String
            switch source {
            case let .spot(market, _):
                link = "https://mixin.one/markets/\(market.coinID)"
                referralParameter = "?ref="
            case let .perpetual(viewModel, _, _):
                link = "https://mixin.one/trade?type=perps&market=\(viewModel.market.marketID)"
                referralParameter = "&referral="
            }
            if let identityNumber = LoginManager.shared.account?.identityNumber {
                link += referralParameter + identityNumber
            }
            UIPasteboard.general.string = link
        }
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        presentingViewController?.dismiss(animated: true)
    }
    
    func savePhoto() {
        reporter.report(
            event: .marketShare,
            tags: ["type": reportingType, "target": "save_to_album"]
        )
        let image = ShareCardImage.render(
            view: contentView,
            padsToSquare: false
        )
        PhotoLibrary.saveImage(source: .image(image)) { alert in
            self.present(alert, animated: true)
        }
    }
    
    func shareToMixinContact() async throws {
        reporter.report(
            event: .marketShare,
            tags: ["type": reportingType, "target": "mixin_contact"]
        )
        view.layoutIfNeeded()
        let image = ShareCardImage.render(view: coverView, padsToSquare: true)
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw URLError(.cannotDecodeContentData)
        }
        let coverURL = try await ShareCardImage.upload(imageData: imageData)
        try Task.checkCancellation()
        let description: String
        var actions: [AppCardData.V1Content.Action]
        switch source {
        case let .spot(market, _):
            description = [
                R.string.localizable.market_share_card_asset(market.name, market.symbol),
                R.string.localizable.market_share_card_market_cap(market.localizedMarketCap),
                R.string.localizable.market_share_card_price(market.localizedPrice),
                R.string.localizable.market_share_card_price_change(market.localizedPriceChangePercentage24H),
            ].joined(separator: "\n")
            actions = [
                .init(
                    action: "mixin://mixin.one/markets/\(market.coinID)",
                    color: "#3D75E3",
                    label: R.string.localizable.market_share_card_market_button()
                ),
            ]
            if let assetID = market.assetIDs?.first {
                let tradingAssetID = assetID == AssetID.erc20USDT ? AssetID.erc20USDC : AssetID.erc20USDT
                let referral = if let identityNumber = LoginManager.shared.account?.identityNumber {
                    "&referral=\(identityNumber)"
                } else {
                    ""
                }
                actions.insert(
                    contentsOf: [
                        .init(
                            action: "mixin://mixin.one/trade?type=swap&input=\(tradingAssetID)&output=\(assetID)" + referral,
                            color: "#27AE60",
                            label: R.string.localizable.buy_token(market.symbol)
                        ),
                        .init(
                            action: "mixin://mixin.one/trade?type=swap&input=\(assetID)&output=\(tradingAssetID)" + referral,
                            color: "#EB5757",
                            label: R.string.localizable.sell_token(market.symbol)
                        ),
                    ],
                    at: 0,
                )
            }
        case let .perpetual(viewModel, _, _):
            let market = viewModel.market
            let marketLink = "mixin://mixin.one/trade?type=perps&market=\(market.marketID)"
            description = [
                R.string.localizable.market_share_card_asset(symbol, R.string.localizable.perpetual()),
                R.string.localizable.perps_share_card_max_leverage(market.leverage),
                R.string.localizable.market_share_card_price(localizedPrice),
                R.string.localizable.perps_share_card_volume(viewModel.volume),
            ].joined(separator: "\n")
            actions = [
                .init(
                    action: marketLink + "&action=open&side=long",
                    color: "#50BD5C",
                    label: R.string.localizable.long()
                ),
                .init(
                    action: marketLink + "&action=open&side=short",
                    color: "#DB454F",
                    label: R.string.localizable.short()
                ),
                .init(
                    action: marketLink,
                    color: "#3D75E3",
                    label: R.string.localizable.market()
                ),
            ]
        }
        let content = AppCardData.V1Content(
            appID: BotUserID.mixinRoute,
            cover: .plain(coverURL),
            title: R.string.localizable.market_share_card_title(symbol),
            description: description,
            actions: actions,
            updatedAt: nil,
            isShareable: true
        )
        try presentShareConfirmation(content: content)
    }
    
}

extension ShareMarketContentViewController {
    
    private class ActivityItem: NSObject, UIActivityItemSource {
        
        private let title: String
        private let image: UIImage
        
        init(title: String, image: UIImage) {
            self.title = title
            self.image = image
            super.init()
        }
        
        func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
            image
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            image
        }
        
        func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
            let meta = LPLinkMetadata()
            meta.imageProvider = NSItemProvider(object: image)
            meta.title = title
            return meta
        }
        
    }
    
}

extension ShareMarketContentViewController: ChartView.Delegate {
    
    func chartView(_ view: ChartView, extremumAnnotationForPoint point: ChartView.Point) -> String {
        CurrencyFormatter.localizedString(
            from: point.value * Currency.current.decimalRate,
            format: .fiatMoneyPrice,
            sign: .never,
            symbol: .currencySymbol
        )
    }
    
    func chartView(_ view: ChartView, inspectionAnnotationForPoint point: ChartView.Point) -> String {
        ""
    }
    
    func chartView(_ view: ChartView, didSelectPoint point: ChartView.Point) {
        
    }
    
    func chartViewDidCancelSelection(_ view: ChartView) {
        
    }
    
}
