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
    
    var sticker: StickerItem?
    
    var stickers = [StickerItem]()
    private lazy var backgroundButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor.black.withAlphaComponent(0)
        button.addTarget(self, action: #selector(backgroundTappingAction), for: .touchUpInside)
        return button
    }()
    
    class func instance() -> StickerPreviewViewController {
        R.storyboard.chat.sticker_preview()!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 13
        updatePreferredContentSizeHeight()
        if let sticker = sticker {
            stickerView.load(sticker: sticker)
            stickerView.startAnimating()
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
        return stickerPreviewViewTopConstraint.constant
            + stickerPreviewViewHeightConstraint.constant
            + AppDelegate.current.mainWindow.safeAreaInsets.bottom
            + (stickers.count > 0 ? 160.0 : 90.0)
    }
    
    private func fetchStickersFromStore() {
        activityIndicatorView.isHidden = false
        activityIndicatorView.startAnimating()
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                self.activityIndicatorView.isHidden = true
                self.activityIndicatorView.stopAnimating()
                self.stickersContentView.isHidden = false
                // update date
                self.collectionView.isHidden = false
                self.collectionView.reloadData()
                self.updatePreferredContentSizeHeight()
            }
        }
    }
    
    private var isStoreSticker: Bool {
        return true
    }
    
}

extension StickerPreviewViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_preview, for: indexPath)!
        if indexPath.row < stickers.count {
            cell.stickerView.load(sticker: stickers[indexPath.item])
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

extension StickerPreviewViewController {
    
    func dismissAsChild(completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame.origin.y = self.backgroundButton.bounds.height
            self.backgroundButton.backgroundColor = UIColor.black.withAlphaComponent(0)
        }) { (finished) in
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
            self.backgroundButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        }
    }
        
}
