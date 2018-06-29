import UIKit
import SnapKit

class StickerPanelViewController: UIViewController {

    @IBOutlet weak var albumsCollectionView: UICollectionView!
    @IBOutlet weak var pagesScrollView: UIScrollView!
    @IBOutlet weak var pagesContentView: UIView!
    
    private var albums = [Album]()
    private var pages = [StickerPageViewController]()
    private var contentViewWidthConstraint: Constraint!
    private var currentPage = 0
    private var isFastScrolling = false
    private var numberOfAlbums: Int {
        return albums.count + 2
    }
    
    private let albumCellReuseId = "AlbumCollectionViewCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pagesContentView.snp.makeConstraints { (make) in
            contentViewWidthConstraint = make.width.equalToSuperview().constraint
        }
        albumsCollectionView.dataSource = self
        albumsCollectionView.delegate = self
        pagesScrollView.delegate = self

        NotificationCenter.default.addObserver(forName: .StickerDidChange, object: nil, queue: .main) { [weak self] (_) in
            DispatchQueue.global().async {
                let stickers = StickerDAO.shared.getFavoriteStickers()
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.pages[1].reload(stickers: stickers)
                }
            }
        }
    }
    
    func reloadRecentPage() {
        let limit = StickerPageViewController.numberOfRecentStickers(forLayoutWidth: pagesScrollView.bounds.width)
        DispatchQueue.global().async {
            let stickers = StickerDAO.shared.recentUsedStickers(limit: limit)
            DispatchQueue.main.async {
                self.pages[0].reload(stickers: stickers)
            }
        }
    }
    
    func reload(albums: [Album], stickers: [[Sticker]]) {
        self.albums = albums
        albumsCollectionView.reloadData()
        for page in pages {
            page.willMove(toParentViewController: nil)
            page.view.removeFromSuperview()
            page.removeFromParentViewController()
        }
        assert(stickers.count == numberOfAlbums)
        for index in 0..<stickers.count {
            let page = StickerPageViewController.instance()
            addChildViewController(page)
            pagesContentView.addSubview(page.view)
            page.view.snp.makeConstraints({ (make) in
                make.top.bottom.equalToSuperview()
                if index == 0 {
                    make.leading.equalToSuperview()
                } else {
                    make.leading.equalTo(pages[index - 1].view.snp.trailing)
                    make.width.equalTo(pages[index - 1].view)
                    if index == numberOfAlbums - 1 {
                        make.trailing.equalToSuperview()
                    }
                }
            })
            page.reload(stickers: stickers[index])
            pages.append(page)
            page.didMove(toParentViewController: self)
        }
        pages[0].isRecentPage = true
        pages[1].isFavoritePage = true
        pagesContentView.snp.remakeConstraints { (make) in
            contentViewWidthConstraint = make.width.equalToSuperview().multipliedBy(numberOfAlbums).constraint
        }
        if stickers.count >= 3, stickers[0].count == 0 {
            let contentOffset = CGPoint(x: pagesScrollView.bounds.width * 2, y: 0)
            pagesScrollView.setContentOffset(contentOffset, animated: false)
            albumsCollectionView.selectItem(at: IndexPath(item: 2, section: 0), animated: false, scrollPosition: [])
        } else {
            albumsCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: [])
        }
    }
    
    private func updatePageSelection(force: Bool) {
        var page = Int(round((pagesScrollView.contentOffset.x / pagesScrollView.contentSize.width) * CGFloat(numberOfAlbums)))
        page = max(0, min(numberOfAlbums - 1, page))
        guard page != currentPage || force else {
            return
        }
        let indexPath = IndexPath(item: page, section: 0)
        albumsCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        currentPage = page
    }
    
}

extension StickerPanelViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numberOfAlbums
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: albumCellReuseId, for: indexPath) as! AlbumCollectionViewCell
        if indexPath.row == 0 {
            cell.imageView.image = #imageLiteral(resourceName: "ic_recent_stickers")
            cell.imageView.contentMode = .center
        } else if indexPath.row == 1 {
            cell.imageView.image = #imageLiteral(resourceName: "ic_sticker_favorite")
            cell.imageView.contentMode = .center
        } else if let url = URL(string: albums[indexPath.row - 2].iconUrl) {
            cell.imageView.sd_setImage(with: url, completed: nil)
            cell.imageView.contentMode = .scaleAspectFit
        }
        return cell
    }
    
}

extension StickerPanelViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let offset = CGPoint(x: CGFloat(indexPath.row) * collectionView.bounds.width, y: 0)
        pagesScrollView.setContentOffset(offset, animated: true)
        isFastScrolling = true
    }
    
}

extension StickerPanelViewController: UIScrollViewDelegate {
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView == pagesScrollView else {
            return
        }
        isFastScrolling = false
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == pagesScrollView else {
            return
        }
        if !isFastScrolling {
            updatePageSelection(force: false)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == pagesScrollView else {
            return
        }
        updatePageSelection(force: true)
    }
    
}
