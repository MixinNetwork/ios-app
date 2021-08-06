import UIKit
import MixinServices

class StickerPreviewViewController: UIViewController {
    
    @IBOutlet weak var stickersContentView: UIView!
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var stickerView: AnimatedStickerView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var stickerPreviewViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickerPreviewViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickersContentViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickersContentViewHeightConstraint: NSLayoutConstraint!
    
    var message: MessageItem!
    
    private var stickerStoreItem: StickerStoreItem?
    private lazy var backgroundButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .black.withAlphaComponent(0)
        button.addTarget(self, action: #selector(backgroundTappingAction), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updatePreferredContentSizeHeight()
        stickerView.load(message: message)
        stickerView.startAnimating()
        if message.assetCategory == "SYSTEM", let stickerId = message.stickerId {
            loadSticker(with: stickerId)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        DispatchQueue.main.async {
            self.updatePreferredContentSizeHeight()
        }
    }
    
    @IBAction func dimissAction(_ sender: Any) {
        dismissAsChild(completion: nil)
    }
    
    @IBAction func addStickersAction(_ sender: Any) {
        guard let album = stickerStoreItem?.album else {
            return
        }
        StickersStoreManager.shared().add(album: album)
        dismissAsChild(completion: nil)
    }
    
}

extension StickerPreviewViewController {
    
    @objc private func backgroundTappingAction() {
        dismissAsChild(completion: nil)
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
        let contentHeight = stickerPreviewViewTopConstraint.constant
            + stickerPreviewViewHeightConstraint.constant
            + window.safeAreaInsets.bottom
            + ((stickerStoreItem != nil && !stickerStoreItem!.stickers.isEmpty) ? 160 : 90)
        return min(maxHeight, contentHeight)
    }
    
    private func loadSticker(with stickerId: String) {
        activityIndicatorView.startAnimating()
        StickersStoreManager.shared().loadSticker(stickerId: stickerId) { item in
            self.activityIndicatorView.stopAnimating()
            if let item = item {
                self.stickerStoreItem = item
                self.stickersContentView.isHidden = false
                self.collectionView.isHidden = false
                self.collectionView.reloadData()
                self.updatePreferredContentSizeHeight()
            } else {
                self.stickersContentView.isHidden = true
                self.collectionView.isHidden = true
            }
        }
    }
    
}

extension StickerPreviewViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let stickerStoreItem = stickerStoreItem else {
            return 0
        }
        return stickerStoreItem.stickers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_preview, for: indexPath)!
        if let stickerStoreItem = stickerStoreItem, indexPath.row < stickerStoreItem.stickers.count {
            cell.stickerView.load(sticker: stickerStoreItem.stickers[indexPath.item])
        }
        return cell
    }
    
}

extension StickerPreviewViewController: UICollectionViewDelegate {
    
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

extension StickerPreviewViewController {
    
    func dismissAsChild(completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame.origin.y = self.backgroundButton.bounds.height
            self.backgroundButton.backgroundColor = .black.withAlphaComponent(0)
        }) { _ in
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
            self.backgroundButton.removeFromSuperview()
            completion?()
        }
    }
    
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
        UIView.animate(withDuration: 0.3) {
            self.view.frame.origin.y = self.backgroundButton.bounds.height - self.preferredContentSize.height
            self.backgroundButton.backgroundColor = .black.withAlphaComponent(0.3)
        }
    }
    
}
