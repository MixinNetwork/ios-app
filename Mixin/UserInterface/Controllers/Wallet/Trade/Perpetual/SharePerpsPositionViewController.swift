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
    
    private var style: SharePerpsPositionStyle = .roe
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
    
    private func makeImage() -> UIImage? {
        let visibleRect = CGRect(
            origin: contentPreviewCollectionView.contentOffset,
            size: contentPreviewCollectionView.frame.size
        )
        let focusCell = contentPreviewCollectionView.visibleCells.max { (one, another) -> Bool in
            let intersectionA = one.frame.intersection(visibleRect).size.width
            let intersectionB = another.frame.intersection(visibleRect).size.width
            return intersectionA < intersectionB
        }
        guard let cell = focusCell else {
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
        switch collectionView {
        case styleSelectorCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            let style = SharePerpsPositionStyle(rawValue: indexPath.item)!
            cell.label.text = switch style {
            case .pnl:
                R.string.localizable.perps_share_pnl()
            case .roe:
                R.string.localizable.perps_share_roe()
            }
            return cell
        case contentPreviewCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.share_perps_position_preview, for: indexPath)!
            cell.load(
                dataSource: dataSource,
                obiContent: obiContent,
                style: style,
                mascotIndex: indexPath.item
            )
            return cell
        default:
            return UICollectionViewCell()
        }
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
            contentPreviewCollectionView.reloadData()
        case contentPreviewCollectionView:
            break
        default:
            break
        }
    }
    
}

extension SharePerpsPositionViewController: ModernShareContentViewController {
    
    func shareToMixinContact() {
        guard let image = makeImage() else {
            return
        }
        presentingViewController?.dismiss(animated: true) {
            let receiverSelector = MessageReceiverViewController.instance(content: .photo(image))
            UIApplication.homeNavigationController?.pushViewController(receiverSelector, animated: true)
        }
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
