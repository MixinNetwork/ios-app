import UIKit
import MixinServices

class StickersAlbumPreviewViewController: ResizablePopupViewController {
    
    @IBOutlet weak var backgroundButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var stickerActionButton: UIButton!
    
    @IBOutlet weak var contentView: UIView!
    
    @IBOutlet weak var hideContentViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var showContentViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleBarHeightConstraint: NSLayoutConstraint!
    
    var stickerStoreItem: StickerStoreItem!
    
    private let cellCountPerRow = 3
    private let initCountOfRows = 3
    private lazy var resizeRecognizerDelegate = PopupResizeGestureCoordinator(scrollView: resizableScrollView)
    private var isShowingContentView = false
    
    class func instance() -> StickersAlbumPreviewViewController {
        R.storyboard.chat.stickers_album_preview()!
    }
    
    override var automaticallyAdjustsResizableScrollViewBottomInset: Bool {
        false
    }
    
    override var resizableScrollView: UIScrollView? {
        collectionView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.maskedCorners = []
        view.layer.cornerRadius = 0
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentView.layer.cornerRadius = 13
        resizeRecognizer.delegate = resizeRecognizerDelegate
        view.addGestureRecognizer(resizeRecognizer)
        showContentViewConstraint.priority = .defaultHigh
        hideContentViewConstraint.priority = .defaultLow
        titleLabel.text = stickerStoreItem.album.name
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let cellCount = CGFloat(cellCountPerRow)
        flowLayout.minimumInteritemSpacing = ((view.bounds.width - cellCount * flowLayout.itemSize.width - flowLayout.sectionInset.horizontal) / (cellCount - 1))
    }
    
    override func preferredContentHeight(forSize size: Size) -> CGFloat {
        view.layoutIfNeeded()
        let window = AppDelegate.current.mainWindow
        let countOfRows: CGFloat
        switch size {
        case .expanded, .unavailable:
            countOfRows = ceil(CGFloat(stickerStoreItem.stickers.count) / CGFloat(cellCountPerRow))
        case .compressed:
            countOfRows = CGFloat(initCountOfRows)
        }
        let maxHeight = window.bounds.height - window.safeAreaInsets.top
        let collectionViewHeight = countOfRows * (flowLayout.itemSize.height + flowLayout.minimumLineSpacing) - flowLayout.minimumLineSpacing
        let height = titleBarHeightConstraint.constant
            + collectionViewHeight
            + window.safeAreaInsets.bottom
            + 102.0
        return min(maxHeight, height)
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
        
    }
    
}

extension StickersAlbumPreviewViewController {
    
    func presentAsChild(of parent: UIViewController) {
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
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
        }
    }
    
}

extension StickersAlbumPreviewViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
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
