import UIKit
import MixinServices

class StickersPreviewViewController: ResizablePopupViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var stickerActionButton: UIButton!
    @IBOutlet weak var titleBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickerActionButtonTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickerActionButtonHeightConstraint: NSLayoutConstraint!
    
    var stickerStoreItem: StickerStoreItem!
    
    private let cellCountPerRow = 3
    private let initCountOfRows = 3
    private lazy var resizeGestureCoordinator = HomeAppResizeGestureCoordinator(scrollView: collectionView)
    private lazy var backgroundButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor.black.withAlphaComponent(0)
        button.addTarget(self, action: #selector(backgroundTappingAction), for: .touchUpInside)
        return button
    }()
    
    class func instance() -> StickersPreviewViewController {
        R.storyboard.chat.stickers_preview()!
    }
    
    override var resizableScrollView: UIScrollView? {
        collectionView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = stickerStoreItem.album.name
        updatePreferredContentSizeHeight(size: size)
        view.addGestureRecognizer(resizeRecognizer)
        resizeRecognizer.delegate = resizeGestureCoordinator
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let cellCount = CGFloat(cellCountPerRow)
        flowLayout.minimumInteritemSpacing = ((view.bounds.width - cellCount * flowLayout.itemSize.width - flowLayout.sectionInset.horizontal)/(cellCount - 1))
    }
    
    override func updatePreferredContentSizeHeight(size: ResizablePopupViewController.Size) {
        guard !isBeingDismissed else {
            return
        }
        let height = preferredContentHeight(forSize: size)
        preferredContentSize.height = height
        view.frame.origin.y = backgroundButton.bounds.height - height
    }
    
    override func preferredContentHeight(forSize size: Size) -> CGFloat {
        view.layoutIfNeeded()
        let window = AppDelegate.current.mainWindow
        switch size {
        case .expanded, .unavailable:
            return window.bounds.height - window.safeAreaInsets.top
        case .compressed:
            return titleBarHeightConstraint.constant + flowLayout.itemSize.height * 3 + window.safeAreaInsets.bottom + 102
        }
    }
    
    override func changeSizeAction(_ recognizer: UIPanGestureRecognizer) {
        guard size != .unavailable else {
            return
        }
        switch recognizer.state {
        case .began:
            resizableScrollView?.isScrollEnabled = false
            size = size.opposite
            let animator = makeSizeAnimator(destination: size)
            animator.pauseAnimation()
            sizeAnimator = animator
        case .changed:
            if let animator = sizeAnimator {
                let translation = recognizer.translation(in: backgroundButton)
                var fractionComplete = translation.y / (backgroundButton.bounds.height - preferredContentHeight(forSize: .compressed))
                if size == .expanded {
                    fractionComplete *= -1
                }
                animator.fractionComplete = fractionComplete
            }
        case .ended:
            if let animator = sizeAnimator {
                let locationAboveBegan = recognizer.translation(in: backgroundButton).y <= 0
                let isGoingUp = recognizer.velocity(in: backgroundButton).y <= 0
                let locationUnderBegan = recognizer.translation(in: backgroundButton).y >= 0
                let isGoingDown = recognizer.velocity(in: backgroundButton).y >= 0
                let shouldExpand = size == .expanded
                    && ((locationAboveBegan && isGoingUp) || isGoingUp)
                let shouldCompress = size == .compressed
                    && ((locationUnderBegan && isGoingDown) || isGoingDown)
                let shouldReverse = !shouldExpand && !shouldCompress
                let completionSize = shouldReverse ? size.opposite : size
                animator.isReversed = shouldReverse
                animator.addCompletion { (position) in
                    self.size = completionSize
                    self.updatePreferredContentSizeHeight(size: completionSize)
                    self.setNeedsSizeAppearanceUpdated(size: completionSize)
                    self.sizeAnimator = nil
                    recognizer.isEnabled = true
                }
                recognizer.isEnabled = false
                animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            }
        default:
            break
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissAsChild(completion: nil)
    }
    
    @IBAction func stickerButtonAction(_ sender: Any) {
        
    }
    
}

extension StickersPreviewViewController {
    
    @objc func backgroundTappingAction() {
        dismissAsChild(completion: nil)
    }
    
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
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame.origin.y = self.backgroundButton.bounds.height - self.preferredContentSize.height
            self.backgroundButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        })
    }
    
}

extension StickersPreviewViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
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
