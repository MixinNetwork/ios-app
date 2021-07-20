import UIKit
import MixinServices

class StickerInputViewController: UIViewController {
    
    @IBOutlet weak var albumsCollectionView: UICollectionView!
    
    private var pageViewController: UIPageViewController!
    private let modelController = StickerInputModelController()
    private var officialAlbums = [Album]()
    private var currentIndex = NSNotFound
    private var pageScrollView: UIScrollView?
    private var isScrollingByAlbumSelection = false
    private var currentPage: StickersCollectionViewController!
    
    var numberOfAllAlbums: Int {
        return officialAlbums.count + modelController.numberOfFixedControllers
    }
    
    var animated = false {
        didSet {
            if animated {
                updatePagesAnimation()
            } else {
                for case let vc as StickersCollectionViewController in pageViewController.children {
                    vc.animated = false
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pageViewController.delegate = self
        albumsCollectionView.dataSource = self
        albumsCollectionView.delegate = self
        pageScrollView = pageViewController.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView
        pageScrollView?.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.animated = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.animated = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let page = segue.destination as? UIPageViewController {
            pageViewController = page
        }
    }
    
    func reload() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.officialAlbums = AlbumDAO.shared.getAlbums()
            self.modelController.reloadRecentFavoriteStickers()
            self.modelController.reloadOfficialStickers(albums: self.officialAlbums)
            DispatchQueue.main.async {
                self.albumsCollectionView.reloadData()
                let initialViewControllers: [UIViewController]
                if let initialViewController = self.modelController.initialViewController {
                    initialViewControllers = [initialViewController]
                    let index = initialViewController.index
                    self.currentIndex = index
                    self.selectAlbum(at: index)
                    self.currentPage = initialViewController
                } else {
                    initialViewControllers = []
                }
                self.pageViewController.setViewControllers(initialViewControllers, direction: .forward, animated: false, completion: nil)
                self.pageViewController.dataSource = self.modelController
            }
        }
    }
    
}

extension StickerInputViewController: ConversationInputInteractiveResizableViewController {
    
    var interactiveResizableScrollView: UIScrollView {
        return currentPage.collectionView
    }
    
}

extension StickerInputViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numberOfAllAlbums
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_album, for: indexPath)!
        switch indexPath.row {
        case 0:
            cell.imageView.image = R.image.ic_sticker_store()
            cell.imageView.contentMode = .center
        case 1:
            cell.imageView.image = R.image.ic_recent_stickers()
            cell.imageView.contentMode = .center
        case 2:
            cell.imageView.image = R.image.ic_sticker_favorite()
            cell.imageView.contentMode = .center
        case 3:
            cell.imageView.image = R.image.ic_gif()
            cell.imageView.contentMode = .center
        default:
            let album = officialAlbums[indexPath.row - modelController.numberOfFixedControllers]
            if let url = URL(string: album.iconUrl) {
                let context = stickerLoadContext(category: album.category)
                cell.imageView.sd_setImage(with: url, placeholderImage: nil, context: context)
            }
            cell.imageView.contentMode = .scaleAspectFit
        }
        return cell
    }
    
}

extension StickerInputViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedIndex = indexPath.item
        if selectedIndex == 0 {
            let viewController = StickerStoreViewController.instance()
            viewController.modalPresentationStyle = .fullScreen
            present(viewController, animated: true, completion: nil)
            return
        }
        guard selectedIndex != currentIndex, !isScrollingByAlbumSelection else {
            return
        }
        guard let viewController = modelController.dequeueReusableStickersViewController(withIndex: selectedIndex) else {
            return
        }
        let direction: UIPageViewController.NavigationDirection = selectedIndex > currentIndex ? .forward : .reverse
        pageViewController.view.isUserInteractionEnabled = false
        isScrollingByAlbumSelection = true
        pageViewController.setViewControllers([viewController], direction: direction, animated: true) { (_) in
            self.updatePagesAnimation()
            self.pageViewController.view.isUserInteractionEnabled = true
            self.isScrollingByAlbumSelection = false
        }
        currentIndex = selectedIndex
        selectAlbum(at: selectedIndex)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let selectedIndexPaths = albumsCollectionView.indexPathsForSelectedItems, selectedIndexPaths.contains(indexPath) else {
            return
        }
        cell.isSelected = true
    }
    
}

extension StickerInputViewController: UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        albumsCollectionView.isUserInteractionEnabled = false
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if finished {
            albumsCollectionView.isUserInteractionEnabled = true
        }
        if let viewController = pageViewController.viewControllers?.first as? StickersCollectionViewController {
            currentIndex = viewController.index
        }
    }
    
}

extension StickerInputViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == pageScrollView, !isScrollingByAlbumSelection else {
            return
        }
        var maxWidth: CGFloat = 0
        var focusedIndex = currentIndex
        for case let vc as StickersCollectionViewController in pageViewController.children where vc.view.superview != nil {
            let convertedFrame = vc.view.convert(vc.view.bounds, to: view)
            let width = view.frame.intersection(convertedFrame).width
            if width > maxWidth {
                maxWidth = width
                focusedIndex = vc.index
                currentPage = vc
            }
        }
        selectAlbum(at: focusedIndex)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == pageScrollView else {
            return
        }
        updatePagesAnimation()
    }
    
}

extension StickerInputViewController {
    
    private func selectAlbum(at index: Int) {
        guard index >= 0 && index < numberOfAllAlbums else {
            return
        }
        let indexPath = IndexPath(item: index, section: 0)
        if let position = suggestScrollPosition(forItemAt: indexPath) {
            if index == 0 {
                albumsCollectionView.setContentOffset(.zero, animated: true)
            } else if index == numberOfAllAlbums - 1 {
                let x = albumsCollectionView.contentSize.width
                    + albumsCollectionView.contentInset.horizontal
                    - albumsCollectionView.frame.width
                albumsCollectionView.setContentOffset(CGPoint(x: x, y: 0), animated: true)
            } else {
                albumsCollectionView.scrollToItem(at: indexPath, at: position, animated: true)
            }
        }
        if !(albumsCollectionView.indexPathsForSelectedItems?.contains(indexPath) ?? false) {
            albumsCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
        }
    }
    
    private func suggestScrollPosition(forItemAt indexPath: IndexPath) -> UICollectionView.ScrollPosition? {
        guard var frame = albumsCollectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame else {
            return nil
        }
        frame.origin.x -= albumsCollectionView.contentOffset.x
        if frame.minX < 0 {
            return .left
        } else if frame.maxX > albumsCollectionView.frame.width {
            return .right
        } else {
            return nil
        }
    }
    
    private func updatePagesAnimation() {
        for case let vc as StickersCollectionViewController in pageViewController.children {
            if vc.index == currentIndex {
                vc.animated = true
            } else {
                vc.animated = false
            }
        }
    }
    
}
