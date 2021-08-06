import UIKit
import MixinServices

class StickersAlbumPreviewViewController: ResizablePopupViewController {
    
    @IBOutlet weak var backgroundButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var stickerActionButton: UIButton!
    
    @IBOutlet weak var hideContentViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var showContentViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var actionBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var actionBarContentHeightConstraint: NSLayoutConstraint!
    
    private lazy var resizeRecognizerDelegate = PopupResizeGestureCoordinator(scrollView: resizableScrollView)
    
    private var stickerStoreItem: StickerStoreItem!
    private var isShowingContentView = false
    private let cellCountPerRow = 3
    private let defaultCountOfRows = 3
    
    class func instance(with stickerStoreItem: StickerStoreItem) -> StickersAlbumPreviewViewController {
        let vc = R.storyboard.chat.stickers_album_preview()!
        vc.stickerStoreItem = stickerStoreItem
        return vc
    }
    
    override var automaticallyAdjustsResizableScrollViewBottomInset: Bool {
        false
    }
    
    override var resizableScrollView: UIScrollView? {
        collectionView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resizeRecognizer.delegate = resizeRecognizerDelegate
        view.addGestureRecognizer(resizeRecognizer)
        view.layer.maskedCorners = []
        view.layer.cornerRadius = 0
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentView.layer.cornerRadius = 13
        showContentViewConstraint.priority = .defaultLow
        hideContentViewConstraint.priority = .defaultHigh
        titleLabel.text = stickerStoreItem.album.name
        actionBarHeightConstraint.constant = AppDelegate.current.mainWindow.safeAreaInsets.bottom
            + actionBarContentHeightConstraint.constant
        if stickerStoreItem.isAdded {
            stickerActionButton.backgroundColor = R.color.red()
            stickerActionButton.setTitle(R.string.localizable.sticker_remove_title(), for: .normal)
        } else {
            stickerActionButton.backgroundColor = R.color.theme()
            stickerActionButton.setTitle(R.string.localizable.sticker_add_title(), for: .normal)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let cellCount = CGFloat(cellCountPerRow)
        flowLayout.itemSize = ScreenWidth.current <= .short ? CGSize(width: 87, height: 87) : CGSize(width: 104, height: 104)
        flowLayout.minimumInteritemSpacing = ((view.bounds.width - cellCount * flowLayout.itemSize.width - flowLayout.sectionInset.horizontal) / (cellCount - 1))
    }
    
    override func preferredContentHeight(forSize size: Size) -> CGFloat {
        view.layoutIfNeeded()
        let countOfRows: CGFloat
        switch size {
        case .expanded, .unavailable:
            countOfRows = ceil(CGFloat(stickerStoreItem.stickers.count) / CGFloat(cellCountPerRow))
        case .compressed:
            countOfRows = CGFloat(defaultCountOfRows)
        }
        let window = AppDelegate.current.mainWindow
        let maxHeight = window.bounds.height - window.safeAreaInsets.top
        let collectionViewHeight = countOfRows * (flowLayout.itemSize.height + flowLayout.minimumLineSpacing) - flowLayout.minimumLineSpacing
        let contentHeight = titleBarHeightConstraint.constant
            + actionBarHeightConstraint.constant
            + collectionViewHeight
        return min(maxHeight, contentHeight)
    }
    
    override func updatePreferredContentSizeHeight(size: ResizablePopupViewController.Size) {
        if size == .expanded {
            UIView.performWithoutAnimation {
                let diff = preferredContentHeight(forSize: .expanded) - preferredContentHeight(forSize: .compressed)
                collectionView.frame.size.height += diff
                collectionView.layoutIfNeeded()
            }
        }
        contentViewHeightConstraint.constant = preferredContentHeight(forSize: size)
        view.layoutIfNeeded()
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissAsChild(completion: nil)
    }
    
    @IBAction func stickerButtonAction(_ sender: Any) {
        StickersStoreManager.shared().handleStickerOperation(with: stickerStoreItem)
        dismissAsChild(completion: nil)
    }
    
}

extension StickersAlbumPreviewViewController {
    
    func presentAsChild(of parent: UIViewController) {
        guard self.parent == nil else {
            return
        }
        loadViewIfNeeded()
        parent.addChild(self)
        parent.view.addSubview(view)
        view.snp.makeEdgesEqualToSuperview()
        didMove(toParent: parent)
        guard !isShowingContentView else {
            return
        }
        isShowingContentView = true
        hideContentViewConstraint.priority = .defaultLow
        showContentViewConstraint.priority = .defaultHigh
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            self.view.layoutIfNeeded()
            self.view.backgroundColor = .black.withAlphaComponent(0.4)
        }
    }
    
    func dismissAsChild(completion: (() -> Void)?) {
        isShowingContentView = false
        hideContentViewConstraint.priority = .defaultHigh
        showContentViewConstraint.priority = .defaultLow
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            self.view.layoutIfNeeded()
            self.view.backgroundColor = .black.withAlphaComponent(0)
        } completion: { _ in
            guard self.parent != nil else {
                return
            }
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
        }
    }
    
}

extension StickersAlbumPreviewViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickerStoreItem.stickers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.stickers_preview_cell, for: indexPath)!
        if indexPath.row < stickerStoreItem.stickers.count {
            cell.stickerView.load(sticker: stickerStoreItem.stickers[indexPath.item])
        }
        return cell
    }
    
}

extension StickersAlbumPreviewViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerPreviewCell else {
            return
        }
        cell.stickerView.startAnimating()
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerPreviewCell else {
            return
        }
        cell.stickerView.stopAnimating()
    }
    
}
