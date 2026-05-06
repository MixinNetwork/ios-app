import UIKit
import LinkPresentation
import MixinServices

final class ShareMarketViewController: ShareViewAsPictureViewController<ShareMarketAsPictureView> {
    
    private let market: Market
    
    init(
        market: Market,
        period: PriceHistoryPeriod,
        points: [ChartView.Point],
        statistics: MarketStatistics,
    ) {
        self.market = market
        let contentView = R.nib.shareMarketAsPictureView(withOwner: nil)!
        contentView.titleLabel.text = market.symbol
        contentView.rankLabel.text = market.numberedRank
        contentView.rankLabel.isHidden = contentView.rankLabel.text == nil
        contentView.tokenIconView.setIcon(market: market)
        contentView.priceLabel.text = market.localizedPrice
        if points.count >= 2 {
            let base = points[0]
            let now = points[points.count - 1]
            let change = (now.value - base.value) / base.value
            if let changePercentage = NumberFormatter.percentage.string(decimal: change) {
                contentView.changeLabel.text = changePercentage
                contentView.changeLabel.alpha = 1
            } else {
                contentView.changeLabel.alpha = 0
            }
            contentView.changeLabel.marketColor = .byValue(change)
            contentView.chartView.points = points
            contentView.hideUnavailableView()
        } else {
            contentView.changeLabel.alpha = 0
            contentView.showUnavailableView()
        }
        if let index = PriceHistoryPeriod.allCases.firstIndex(of: period) {
            contentView.setPeriodSelection(index: index)
        }
        contentView.nameLabel.text = market.name
        contentView.marketCapContentLabel.text = statistics.marketCap
        contentView.volumeContentLabel.text = statistics.fiatMoneyVolume24H
        contentView.highContentLabel.text = statistics.high24H
        contentView.lowContentLabel.text = statistics.low24H
        super.init(contentView: contentView, size: CGSize(width: 295, height: 690))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        actionButtonBackgroundView.effect = nil
        actionButtonTrayView.backgroundColor = R.color.background()
    }
    
    override func share(_ sender: Any) {
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
    
    override func copyLink(_ sender: Any) {
        UIPasteboard.general.string = URL.shortMixinMessenger.absoluteString
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        close(sender)
    }
    
    override func savePhoto(_ sender: Any) {
        let image = makeImage()
        PhotoLibrary.saveImage(source: .image(image)) { alert in
            self.present(alert, animated: true)
        }
    }
    
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
