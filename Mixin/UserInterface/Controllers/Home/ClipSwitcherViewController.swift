import UIKit

class ClipSwitcherViewController: UIViewController {
    
    @IBOutlet weak var backgroundView: UIVisualEffectView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var removeAllButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    @IBOutlet var tapRecognizer: UITapGestureRecognizer!
    
    @IBOutlet weak var removeAllButtonTopConstraint: NSLayoutConstraint!
    
    private(set) var isShowing = false
    
    private let numberOfRows = 3
    private let numberOfColumns = 2
    
    var clips: [Clip] = [] {
        didSet {
            if isViewLoaded {
                reloadData()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let pageInset = UIEdgeInsets(top: 0, left: 20, bottom: 118, right: 20)
        let layout = ClipSwitcherThumbnailFlowLayout(numberOfRows: numberOfRows,
                                                     numberOfColumns: numberOfColumns,
                                                     interitemSpacing: 16,
                                                     lineSpacing: 16,
                                                     pageInset: pageInset)
        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        reloadData()
        tapRecognizer.delegate = self
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    @IBAction func removeAll(_ sender: Any) {
        let controller = UIAlertController(title: R.string.localizable.clip_remove_all(), message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: R.string.localizable.action_remove_all(), style: .destructive, handler: { (_) in
            self.collectionView.performBatchUpdates {
                let indexPaths = (0..<self.clips.count).map {
                    IndexPath(item: $0, section: 0)
                }
                self.clips = []
                self.collectionView.deleteItems(at: indexPaths)
            } completion: { (_) in
                self.hide()
            }
            UIApplication.homeContainerViewController?.clipSwitcher.replaceClips(with: [])
        }))
        controller.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
    @IBAction func pageControlValueChanged(_ pageControl: UIPageControl) {
        let x = CGFloat(pageControl.currentPage) * collectionView.frame.width
        let offset = CGPoint(x: x, y: 0)
        collectionView.setContentOffset(offset, animated: true)
    }
    
    @IBAction func hide() {
        guard parent != nil else {
            return
        }
        isShowing = false
        UIApplication.homeContainerViewController?.setNeedsStatusBarAppearanceUpdate()
        UIView.animate(withDuration: 0.3) {
            self.backgroundView.effect = nil
            self.collectionView.alpha = 0
            self.closeButton.alpha = 0
            self.removeAllButton.alpha = 0
        } completion: { (_) in
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
        }
    }
    
    func show() {
        guard parent == nil else {
            return
        }
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        AppDelegate.current.mainWindow.endEditing(true)
        isShowing = true
        UIApplication.homeContainerViewController?.setNeedsStatusBarAppearanceUpdate()
        loadViewIfNeeded()
        backgroundView.effect = nil
        collectionView.alpha = 0
        closeButton.alpha = 0
        removeAllButton.alpha = 0
        container.addChild(self)
        container.view.addSubview(self.view)
        self.didMove(toParent: container)
        UIView.animate(withDuration: 0.3) {
            self.backgroundView.effect = .darkBlur
            self.collectionView.alpha = 1
            self.closeButton.alpha = 1
            self.removeAllButton.alpha = 1
        }
    }
    
    private func reloadData() {
        collectionView.reloadData()
        let itemsPerPage = numberOfRows * numberOfColumns
        let numberOfPages = ceil(Double(clips.count) / Double(itemsPerPage))
        pageControl.numberOfPages = Int(numberOfPages)
    }
    
    private func dragOrDropPreviewParameters(forItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ClipThumbnailCell else {
            return nil
        }
        let param = UIDragPreviewParameters()
        let radii = CGSize(width: cell.contentWrapperView.layer.cornerRadius,
                           height: cell.contentWrapperView.layer.cornerRadius)
        param.visiblePath = UIBezierPath(roundedRect: cell.bounds,
                                         byRoundingCorners: .allCorners,
                                         cornerRadii: radii)
        return param
    }
    
}

extension ClipSwitcherViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        clips.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.clip_thumbnail, for: indexPath)!
        let clip = clips[indexPath.item]
        cell.titleLabel.text = clip.title
        if let app = clip.app {
            cell.appAvatarImageView.setImage(app: app)
            cell.appAvatarImageView.isHidden = false
        } else {
            cell.appAvatarImageView.isHidden = true
        }
        if let thumbnail = clip.thumbnail {
            cell.thumbnailImageView.image = thumbnail
            cell.thumbnailWrapperView.setNeedsLayout()
        }
        cell.delegate = self
        return cell
    }
    
}

extension ClipSwitcherViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = scrollView.contentOffset.x / scrollView.frame.size.width
        pageControl.currentPage = Int(round(page))
    }
    
}

extension ClipSwitcherViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let clip = clips[indexPath.row]
        guard let parent = UIApplication.homeNavigationController?.topViewController else {
            return
        }
        guard !parent.children.contains(clip.controller) else {
            hide()
            return
        }
        func present() {
            hide()
            clip.controller.presentAsChild(of: parent) {
                parent.children
                    .compactMap { $0 as? MixinWebViewController }
                    .filter { $0 != clip.controller }
                    .forEach { $0.dismissAsChild(animated: false) }
            }
        }
        if let presented = parent.presentedViewController {
            presented.dismiss(animated: true, completion: present)
        } else {
            present()
        }
    }
    
}

extension ClipSwitcherViewController: UICollectionViewDragDelegate {
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let provider = NSItemProvider(object: "\(indexPath)" as NSString)
        let item = UIDragItem(itemProvider: provider)
        item.localObject = clips[indexPath.row]
        return [item]
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        dragOrDropPreviewParameters(forItemAt: indexPath)
    }
    
}

extension ClipSwitcherViewController: UICollectionViewDropDelegate {
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if collectionView.hasActiveDrag {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        } else {
            return UICollectionViewDropProposal(operation: .forbidden)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard coordinator.proposal.operation == .move else {
            return
        }
        guard let item = coordinator.items.first, let sourceIndexPath = item.sourceIndexPath else {
            return
        }
        let destinationIndexPath: IndexPath
        if let indexPath = coordinator.destinationIndexPath {
            destinationIndexPath = indexPath
        } else {
            destinationIndexPath = IndexPath(item: 0, section: 0)
        }
        collectionView.performBatchUpdates {
            let clip = self.clips.remove(at: sourceIndexPath.item)
            self.clips.insert(clip, at: destinationIndexPath.item)
            collectionView.moveItem(at: sourceIndexPath, to: destinationIndexPath)
        } completion: { (_) in
            UIApplication.homeContainerViewController?.clipSwitcher.replaceClips(with: self.clips)
        }
        coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        dragOrDropPreviewParameters(forItemAt: indexPath)
    }
    
}

extension ClipSwitcherViewController: ClipThumbnailCellDelegate {
    
    func clipThumbnailCellDidSelectClose(_ cell: ClipThumbnailCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        collectionView.performBatchUpdates {
            clips.remove(at: indexPath.row)
            collectionView.deleteItems(at: [indexPath])
        } completion: { (_) in
            if self.clips.isEmpty {
                self.hide()
            }
        }
        UIApplication.homeContainerViewController?.clipSwitcher.removeClip(at: indexPath.row)
    }
    
}

extension ClipSwitcherViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: collectionView)
        return collectionView.indexPathForItem(at: location) == nil
    }
    
}
