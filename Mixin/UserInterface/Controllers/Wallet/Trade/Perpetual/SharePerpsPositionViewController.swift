import UIKit
import MixinServices

final class SharePerpsPositionViewController: UIViewController {
    
    @IBOutlet weak var styleSelectorCollectionView: UICollectionView!
    @IBOutlet weak var styleSelectorLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var contentPreviewCollectionView: UICollectionView!
    @IBOutlet weak var contentPreviewLayout: SharePerpsPositionCarouselLayout!
    
    @IBOutlet weak var styleSelectorHeightConstraint: NSLayoutConstraint!
    
    private let dataSource: SharePerpetualPositionDataSource
    private let obiContent: ShareObiView.Content
    
    private var style: SharePerpsPositionStyle = .pnl
    private var styleSelectorSizeObserver: NSKeyValueObservation?
    private var layoutContentPreviewWidth: CGFloat?
    
    init(
        dataSource: SharePerpetualPositionDataSource,
        rebatingCode: Referral.RebatingCode?,
    ) {
        self.dataSource = dataSource
        self.obiContent = if let rebatingCode {
            .referral(rebatingCode)
        } else {
            .installMixin
        }
        let nib = R.nib.sharePerpsPositionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        styleSelectorLayout.itemSize = UICollectionViewFlowLayout.automaticSize
        styleSelectorCollectionView.register(R.nib.exploreSegmentCell)
        styleSelectorSizeObserver = styleSelectorCollectionView.observe(
            \.contentSize,
             options: [.new]
        ) { [weak self] (_, change) in
            guard let newValue = change.newValue, let self else {
                return
            }
            self.styleSelectorHeightConstraint.constant = newValue.height
            self.view.layoutIfNeeded()
        }
        styleSelectorCollectionView.dataSource = self
        styleSelectorCollectionView.delegate = self
        styleSelectorCollectionView.reloadData()
        styleSelectorCollectionView.selectItem(
            at: IndexPath(item: 0, section: 0),
            animated: false,
            scrollPosition: []
        )
        
        contentPreviewCollectionView.decelerationRate = .fast
        contentPreviewCollectionView.register(R.nib.sharePerpsPositionPreviewCell)
        contentPreviewCollectionView.dataSource = self
        contentPreviewCollectionView.delegate = self
        contentPreviewCollectionView.reloadData()
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        updateContentPreviewContentInsetsIfNeeded()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateContentPreviewContentInsetsIfNeeded()
    }
    
    private func updateContentPreviewContentInsetsIfNeeded() {
        let width = contentPreviewCollectionView.bounds.width
        guard layoutContentPreviewWidth != width else {
            return
        }
        let horizontalInset = (width - contentPreviewLayout.itemSize.width) / 2
        contentPreviewLayout.sectionInset = UIEdgeInsets(
            top: 0,
            left: horizontalInset,
            bottom: 0,
            right: horizontalInset
        )
        layoutContentPreviewWidth = width
    }
    
    private func updateStyleSelection() {
        let visibleRect = CGRect(
            origin: contentPreviewCollectionView.contentOffset,
            size: contentPreviewCollectionView.frame.size
        )
        let focusCell = contentPreviewCollectionView.visibleCells.max { (one, another) -> Bool in
            let intersectionA = one.frame.intersection(visibleRect).size.width
            let intersectionB = another.frame.intersection(visibleRect).size.width
            return intersectionA < intersectionB
        }
        guard let focusCell, let indexPath = contentPreviewCollectionView.indexPath(for: focusCell) else {
            return
        }
        style = SharePerpsPositionStyle(rawValue: indexPath.item)!
        styleSelectorCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
    
    private func makeImage() -> UIImage? {
        let indexPath = IndexPath(item: style.rawValue, section: 0)
        guard let cell = contentPreviewCollectionView.cellForItem(at: indexPath) else {
            return nil
        }
        let canvas = cell.contentView.bounds
        let renderer = UIGraphicsImageRenderer(bounds: canvas)
        let cornerRadius = cell.contentView.layer.cornerRadius
        cell.contentView.layer.cornerRadius = 0
        let image = renderer.image { context in
            cell.contentView.drawHierarchy(in: canvas, afterScreenUpdates: true)
        }
        cell.contentView.layer.cornerRadius = cornerRadius
        return image
    }
    
}

extension SharePerpsPositionViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        SharePerpsPositionStyle.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let style = SharePerpsPositionStyle(rawValue: indexPath.item)!
        switch collectionView {
        case styleSelectorCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            cell.label.text = switch style {
            case .pnl:
                R.string.localizable.perps_share_pnl()
            case .roe:
                R.string.localizable.perps_share_roe()
            }
            return cell
        case contentPreviewCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.share_perps_position_preview, for: indexPath)!
            cell.load(dataSource: dataSource, obiContent: obiContent, style: style)
            return cell
        default:
            return UICollectionViewCell()
        }
    }
    
}

extension SharePerpsPositionViewController: UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == contentPreviewCollectionView else {
            return
        }
        updateStyleSelection()
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView == contentPreviewCollectionView else {
            return
        }
        updateStyleSelection()
    }
    
}

extension SharePerpsPositionViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch collectionView {
        case styleSelectorCollectionView:
            style = SharePerpsPositionStyle(rawValue: indexPath.item)!
            contentPreviewCollectionView.scrollToItem(
                at: indexPath,
                at: .centeredHorizontally,
                animated: true
            )
        case contentPreviewCollectionView:
            break
        default:
            break
        }
    }
    
}

extension SharePerpsPositionViewController: ModernShareContentViewController {
    
    func shareToMixinContact() {
        let description = R.string.localizable.perps_share_card_market(dataSource.displaySymbol ?? "")
        + "\n"
        + R.string.localizable.perps_share_card_side(dataSource.side, dataSource.leverageMultiplier)
        let content = AppCardData.V1Content(
            appID: BotUserID.mixinFutures,
            cover: .plain("https://dl.mixinpay.com/perps-share-card.png"),
            title: R.string.localizable.perps_share_card_title(
                dataSource.tokenSymbol ?? ""
            ),
            description: description,
            actions: [
                .init(
                    action: "https://mixin.one/trade?type=perpetual&market=\(dataSource.marketID)",
                    color: "#50BD5C",
                    label: R.string.localizable.perps_share_card_trade_now()
                ),
            ],
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
    
    func shareAsActivity() {
        guard let presentingViewController, let image = makeImage() else {
            return
        }
        let item = QRCodeActivityItem(image: image, title: dataSource.title)
        let activity = UIActivityViewController(
            activityItems: [item],
            applicationActivities: nil
        )
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
        guard let image = makeImage() else {
            return
        }
        PhotoLibrary.saveImage(source: .image(image)) { alert in
            self.present(alert, animated: true)
        }
    }
    
}
