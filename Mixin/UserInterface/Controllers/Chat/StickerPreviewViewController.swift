import UIKit
import MixinServices

final class StickerPreviewViewController: UIViewController {
    
    @IBOutlet weak var stickersContentView: UIView!
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var stickerView: AnimatedStickerView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var stickerActionButton: UIButton!
    
    @IBOutlet weak var stickerPreviewViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickerPreviewViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickerPreviewViewTrailingConstraint: NSLayoutConstraint!
    
    private let message: MessageItem
    private let cellReuseIdentifier = "c"
    
    private var albumItem: AlbumItem?
    
    private lazy var backgroundButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .black.withAlphaComponent(0)
        button.addTarget(self, action: #selector(backgroundTappingAction), for: .touchUpInside)
        return button
    }()
    
    init(message: MessageItem) {
        self.message = message
        let nib = R.nib.stickerPreviewView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 13
        collectionView.register(
            StickerPreviewItemCell.self,
            forCellWithReuseIdentifier: cellReuseIdentifier
        )
        collectionView.dataSource = self
        collectionView.delegate = self
        updatePreferredContentSizeHeight()
        stickerView.load(message: message)
        stickerView.startAnimating()
        if let stickerId = message.stickerId {
            DispatchQueue.global().async { [weak self] in
                if let album = AlbumDAO.shared.getAlbum(stickerId: stickerId, category: .SYSTEM) {
                    let stickers = StickerDAO.shared.getStickers(albumId: album.albumId)
                    let albumItem = AlbumItem(album: album, stickers: stickers)
                    DispatchQueue.main.async {
                        self?.reloadData(albumItem: albumItem)
                    }
                }
                if case let .success(response) = StickerAPI.sticker(stickerId: stickerId) {
                    if let sticker = StickerDAO.shared.insertOrUpdateSticker(sticker: response) {
                        DispatchQueue.main.async {
                            self?.stickerView.load(sticker: sticker)
                        }
                    }
                    if let albumID = response.albumId, !albumID.isEmpty {
                        DispatchQueue.main.async {
                            self?.activityIndicatorView.startAnimating()
                        }
                        if case let .success(album) = StickerAPI.album(albumId: albumID),
                           album.category != AlbumCategory.PERSONAL.rawValue,
                           case let .success(stickers) = StickerAPI.stickers(albumId: albumID)
                        {
                            AlbumDAO.shared.insertOrUpdateAblum(album: album)
                            let stickers = StickerDAO.shared.insertOrUpdateStickers(stickers: stickers, albumId: albumID)
                            let albumItem = AlbumItem(album: album, stickers: stickers)
                            DispatchQueue.main.async {
                                self?.reloadData(albumItem: albumItem)
                            }
                        }
                        DispatchQueue.main.async {
                            self?.activityIndicatorView.stopAnimating()
                        }
                    }
                }
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func dimissAction(_ sender: Any) {
        dismissAsChild()
    }
    
    @IBAction func stickerButtonAction(_ sender: Any) {
        guard let albumItem = albumItem else {
            return
        }
        if albumItem.isAdded {
            StickerStore.remove(item: albumItem)
        } else {
            StickerStore.add(item: albumItem)
        }
        self.albumItem?.isAdded.toggle()
        updateStickerActionButton()
    }
    
}

extension StickerPreviewViewController {
    
    @objc private func backgroundTappingAction() {
        dismissAsChild()
    }
    
    private func updatePreferredContentSizeHeight() {
        guard !isBeingDismissed else {
            return
        }
        let height = preferredContentHeight()
        preferredContentSize.height = height
        view.frame.origin.y = backgroundButton.bounds.height - height
    }
    
    private func preferredContentHeight() -> CGFloat {
        view.layoutIfNeeded()
        let window = AppDelegate.current.mainWindow
        let maxHeight = window.bounds.height - window.safeAreaInsets.top
        let previewHeight = window.bounds.width - stickerPreviewViewLeadingConstraint.constant - stickerPreviewViewTrailingConstraint.constant
        let contentHeight = stickerPreviewViewTopConstraint.constant
            + previewHeight
            + window.safeAreaInsets.bottom
            + ((albumItem != nil && !albumItem!.stickers.isEmpty) ? 168 : 90)
        return min(maxHeight, contentHeight)
    }
    
    private func reloadData(albumItem: AlbumItem?) {
        if let albumItem = albumItem, !albumItem.stickers.isEmpty {
            self.albumItem = albumItem
            titleLabel.text = albumItem.album.name
            updateStickerActionButton()
            stickersContentView.isHidden = false
            collectionView.isHidden = false
            collectionView.reloadData()
            updatePreferredContentSizeHeight()
            if let stickerID = message.stickerId,
               let index = albumItem.stickers.firstIndex(where: { $0.stickerId == stickerID })
            {
                let indexPath = IndexPath(item: index, section: 0)
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredHorizontally)
            }
        } else {
            stickersContentView.isHidden = true
            collectionView.isHidden = true
        }
    }
    
    private func updateStickerActionButton() {
        guard let albumItem = albumItem else {
            return
        }
        if albumItem.isAdded {
            stickerActionButton.setTitle(R.string.localizable.added(), for: .normal)
            stickerActionButton.backgroundColor = R.color.sticker_button_background_disabled()
            stickerActionButton.setTitleColor(R.color.sticker_button_text_disabled(), for: .normal)
        } else {
            stickerActionButton.setTitle(R.string.localizable.add_sticker(), for: .normal)
            stickerActionButton.backgroundColor = R.color.theme()
            stickerActionButton.setTitleColor(.white, for: .normal)
        }
    }
    
}

extension StickerPreviewViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let albumItem = albumItem else {
            return 0
        }
        return albumItem.stickers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as! StickerPreviewItemCell
        if let albumItem = albumItem, indexPath.row < albumItem.stickers.count {
            cell.stickerView.load(sticker: albumItem.stickers[indexPath.item])
        }
        return cell
    }
    
}

extension StickerPreviewViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerPreviewItemCell else {
            return
        }
        cell.stickerView.startAnimating()
        guard let selectedIndexPaths = collectionView.indexPathsForSelectedItems, selectedIndexPaths.contains(indexPath) else {
            return
        }
        cell.isSelected = true
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerPreviewItemCell else {
            return
        }
        cell.stickerView.stopAnimating()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let albumItem = albumItem, indexPath.item < albumItem.stickers.count else {
            return
        }
        stickerView.load(sticker: albumItem.stickers[indexPath.item])
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
    
}

extension StickerPreviewViewController {
        
    func presentAsChild(of parent: UIViewController) {
        loadViewIfNeeded()
        backgroundButton.frame = parent.view.bounds
        backgroundButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.addChild(self)
        parent.view.addSubview(backgroundButton)
        didMove(toParent: parent)
        view.frame = CGRect(x: 0,
                            y: backgroundButton.bounds.height,
                            width: backgroundButton.bounds.width,
                            height: backgroundButton.bounds.height)
        view.autoresizingMask = .flexibleTopMargin
        backgroundButton.addSubview(view)
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            self.view.frame.origin.y = self.backgroundButton.bounds.height - self.preferredContentSize.height
            self.backgroundButton.backgroundColor = .black.withAlphaComponent(0.3)
        }
    }
    
    func dismissAsChild() {
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            self.view.frame.origin.y = self.backgroundButton.bounds.height
            self.backgroundButton.backgroundColor = .black.withAlphaComponent(0)
        } completion: { _ in
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
            self.backgroundButton.removeFromSuperview()
        }
    }
    
}
