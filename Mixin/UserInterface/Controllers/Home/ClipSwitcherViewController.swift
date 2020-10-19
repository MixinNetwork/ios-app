import UIKit

class ClipSwitcherViewController: UIViewController {
    
    @IBOutlet weak var backgroundView: UIVisualEffectView!
    @IBOutlet weak var removeAllButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    @IBOutlet var tapRecognizer: UITapGestureRecognizer!
    
    @IBOutlet weak var removeAllButtonTopConstraint: NSLayoutConstraint!
    
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
        reloadData()
        tapRecognizer.delegate = self
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
            UIApplication.clipSwitcher.removeAll()
        }))
        controller.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
    func show() {
        guard parent == nil else {
            return
        }
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        loadViewIfNeeded()
        backgroundView.effect = nil
        collectionView.alpha = 0
        removeAllButton.alpha = 0
        container.addChild(self)
        container.view.addSubview(self.view)
        self.didMove(toParent: container)
        UIView.animate(withDuration: 0.3) {
            self.backgroundView.effect = .darkBlur
            self.collectionView.alpha = 1
            self.removeAllButton.alpha = 1
        }
    }
    
    @IBAction func hide() {
        UIView.animate(withDuration: 0.3) {
            self.backgroundView.effect = nil
            self.collectionView.alpha = 0
            self.removeAllButton.alpha = 0
        } completion: { (_) in
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
        }
    }
    
    private func reloadData() {
        collectionView.reloadData()
        let itemsPerPage = numberOfRows * numberOfColumns
        let numberOfPages = ceil(Double(clips.count) / Double(itemsPerPage))
        pageControl.numberOfPages = Int(numberOfPages)
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
        if let parent = UIApplication.homeNavigationController?.topViewController {
            func present() {
                let clip = clips[indexPath.row]
                hide()
                clip.controller.presentAsChild(of: parent, completion: nil)
            }
            if let presented = parent.presentedViewController {
                presented.dismiss(animated: true, completion: present)
            } else {
                present()
            }
        }
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
        UIApplication.clipSwitcher.removeClip(at: indexPath.row)
    }
    
}

extension ClipSwitcherViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: collectionView)
        return collectionView.indexPathForItem(at: location) == nil
    }
    
}
