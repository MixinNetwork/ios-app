import UIKit
import LinkPresentation
import MixinServices

final class ShareMarketContentViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var rankLabel: InsetLabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    @IBOutlet weak var tokenIconView: PlainTokenIconView!
    @IBOutlet weak var chartView: ChartView!
    @IBOutlet weak var obiView: ShareObiView!
    
    @IBOutlet weak var contentWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentHeightConstraint: NSLayoutConstraint!
    
    private let market: Market
    private let points: [ChartView.Point]
    private let obiContent: ShareObiView.Content
    
    private weak var unavailableView: UIView?
    
    init(
        market: Market,
        points: [ChartView.Point],
        rebatingCode: Referral.RebatingCode?,
    ) {
        self.market = market
        self.points = points
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
        
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        
        symbolLabel.font = .systemFont(
            ofSize: 14,
            weight: .accessiblityBoldTextCounterWeight(.regular)
        )
        symbolLabel.text = market.symbol
        
        rankLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        rankLabel.layer.masksToBounds = true
        rankLabel.layer.cornerRadius = 4
        rankLabel.font = .systemFont(
            ofSize: 12,
            weight: .accessiblityBoldTextCounterWeight(.medium)
        )
        rankLabel.text = market.numberedRank
        rankLabel.isHidden = rankLabel.text == nil
        
        priceLabel.font = .systemFont(
            ofSize: 22,
            weight: .accessiblityBoldTextCounterWeight(.medium)
        )
        priceLabel.text = market.localizedPrice
        
        changeLabel.font = .systemFont(
            ofSize: 14,
            weight: .accessiblityBoldTextCounterWeight(.regular)
        )
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
            changeLabel.marketColor = .byValue(change)
            chartView.points = points
            hideUnavailableView()
        } else {
            changeLabel.alpha = 0
            showUnavailableView()
        }
        
        obiView.load(gradient: true, content: obiContent)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let scaleX = view.bounds.width / contentWidthConstraint.constant
        let scaleY = view.bounds.height / contentHeightConstraint.constant
        let scale = min(scaleX, scaleY)
        contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
    
    private func showUnavailableView() {
        let unavailableView: UIView
        if let view = self.unavailableView {
            unavailableView = view
        } else {
            unavailableView = PriceDataUnavailableView()
            view.addSubview(unavailableView)
            unavailableView.snp.makeConstraints { make in
                make.edges.equalTo(chartView)
            }
            self.unavailableView = unavailableView
        }
        unavailableView.isHidden = false
    }
    
    private func hideUnavailableView() {
        unavailableView?.isHidden = true
    }
    
    private func makeImage() -> UIImage {
        let canvas = contentView.bounds
        let renderer = UIGraphicsImageRenderer(bounds: canvas)
        let cornerRadius = contentView.layer.cornerRadius
        contentView.layer.cornerRadius = 0
        let image = renderer.image { context in
            contentView.drawHierarchy(in: canvas, afterScreenUpdates: true)
        }
        contentView.layer.cornerRadius = cornerRadius
        return image
    }
    
}

extension ShareMarketContentViewController: ModernShareContentViewController {
    
    func shareAsActivity() {
        guard let presentingViewController else {
            return
        }
        let image = makeImage()
        let item = ActivityItem(
            title: market.symbol + " " + R.string.localizable.market(),
            image: image
        )
        let activity = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        presentingViewController.dismiss(animated: true) {
            presentingViewController.present(activity, animated: true)
        }
    }
    
    func copyLink() {
        UIPasteboard.general.string = obiContent.url
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        presentingViewController?.dismiss(animated: true)
    }
    
    func savePhoto() {
        let image = makeImage()
        PhotoLibrary.saveImage(source: .image(image)) { alert in
            self.present(alert, animated: true)
        }
    }
    
    func shareToMixinContact() {
        var description = R.string.localizable.market_share_card_asset(market.name, market.symbol) + "\n"
        if let marketCap = market.localizedMarketCap {
            description += R.string.localizable.market_share_card_market_cap(marketCap) + "\n"
        }
        description += R.string.localizable.market_share_card_price(market.localizedPrice) + "\n"
        if let priceChange = market.localizedPriceChangePercentage24H {
            description += R.string.localizable.market_share_card_price_change(priceChange)
        }
        var actions: [AppCardData.V1Content.Action] = [
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
        let content = AppCardData.V1Content(
            appID: BotUserID.marketAlerts,
            cover: .plain("https://dl.mixinpay.com/share-market-card.png"),
            title: R.string.localizable.market_share_card_title(market.symbol),
            description: description,
            actions: actions,
            updatedAt: nil,
            isShareable: true
        )
        let cardData: AppCardData = .v1(content)
        var message = Message.createMessage(
            messageId: UUID().uuidString.lowercased(),
            conversationId: "",
            userId: myUserId,
            category: MessageCategory.APP_CARD.rawValue,
            status: MessageStatus.SENDING.rawValue,
            createdAt: Date().toUTCString()
        )
        message.content = try! JSONEncoder.default.encode(cardData).base64EncodedString()
        let confirmation = ExternalSharingConfirmationViewController(
            sharingContext: ExternalSharingContext(content: .appCard(cardData)),
            message: message,
            webContext: nil,
            action: .forward
        )
        UIApplication.homeContainerViewController?.present(confirmation, animated: true)
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
