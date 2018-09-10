import UIKit

class StickerInputViewController: UIViewController {
    
    @IBOutlet weak var albumsCollectionView: UICollectionView!
    
    private var pageViewController: UIPageViewController!
    private let modelController = StickerInputModelController()
    private let albumCellReuseId = "AlbumCollectionViewCell"
    private var officialAlbums = [Album]()
    private var currentIndex = NSNotFound
    private var pageScrollView: UIScrollView?
    private var isScrollingByAlbumSelection = false
    
    var numberOfAllAlbums: Int {
        return officialAlbums.count + 2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pageViewController.delegate = self
        albumsCollectionView.dataSource = self
        albumsCollectionView.delegate = self
        pageScrollView = pageViewController.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView
        pageScrollView?.delegate = self
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
                } else {
                    initialViewControllers = []
                }
                self.pageViewController.setViewControllers(initialViewControllers, direction: .forward, animated: false, completion: nil)
                self.pageViewController.dataSource = self.modelController
            }
        }
    }
    
    static func instance() -> StickerInputViewController {
        return Storyboard.chat.instantiateViewController(withIdentifier: "sticker_input") as! StickerInputViewController
    }
    
}

extension StickerInputViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numberOfAllAlbums
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: albumCellReuseId, for: indexPath) as! AlbumCollectionViewCell
        if indexPath.row == 0 {
            cell.imageView.image = #imageLiteral(resourceName: "ic_recent_stickers")
            cell.imageView.contentMode = .center
        } else if indexPath.row == 1 {
            cell.imageView.image = #imageLiteral(resourceName: "ic_sticker_favorite")
            cell.imageView.contentMode = .center
        } else if let url = URL(string: officialAlbums[indexPath.row - 2].iconUrl) {
            cell.imageView.sd_setImage(with: url, completed: nil)
            cell.imageView.contentMode = .scaleAspectFit
        }
        return cell
    }
    
}

extension StickerInputViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedIndex = indexPath.item
        guard selectedIndex != currentIndex, !isScrollingByAlbumSelection else {
            return
        }
        guard let viewController = modelController.dequeueReusableStickersViewController(withIndex: selectedIndex) else {
            return
        }
        let direction: UIPageViewControllerNavigationDirection = selectedIndex > currentIndex ? .forward : .reverse
        pageViewController.view.isUserInteractionEnabled = false
        isScrollingByAlbumSelection = true
        pageViewController.setViewControllers([viewController], direction: direction, animated: true) { (_) in
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
        if let viewController = pageViewController.viewControllers?.first as? StickersViewController {
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
        for case let vc as StickersViewController in pageViewController.childViewControllers {
            guard vc.view.superview != nil else {
                continue
            }
            let convertedFrame = vc.view.convert(vc.view.bounds, to: view)
            let width = view.frame.intersection(convertedFrame).width
            if width > maxWidth {
                maxWidth = width
                focusedIndex = vc.index
            }
        }
        selectAlbum(at: focusedIndex)
    }
    
}

extension StickerInputViewController {
    
    private func selectAlbum(at index: Int) {
        guard index >= 0 && index < numberOfAllAlbums else {
            return
        }
        let indexPath = IndexPath(item: index, section: 0)
        if let selectedIndexPaths = albumsCollectionView.indexPathsForSelectedItems, selectedIndexPaths.contains(indexPath) {
            return
        }
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
        albumsCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
    }
    
    private func suggestScrollPosition(forItemAt indexPath: IndexPath) -> UICollectionViewScrollPosition? {
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
    
}
