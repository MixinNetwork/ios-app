import UIKit
import MixinServices

class StickersStoreViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    private let maxBannerCount = 3

    private var bannerItems = [AlbumItem]()
    private var listItems = [AlbumItem]()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateAlbumAddStatus(_:)),
                                               name: AlbumDAO.addedAlbumsDidChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadData),
                                               name: RefreshAlbumJob.didRefreshNotification,
                                               object: nil)
        reloadData()
        ConcurrentJobQueue.shared.addJob(job: RefreshAlbumJob())
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        flowLayout.itemSize = CGSize(width: view.bounds.width, height: 104)
        if bannerItems.isEmpty {
            flowLayout.headerReferenceSize = .zero
        } else {
            let size = ScreenWidth.current <= .short
                ? CGSize(width: view.bounds.width, height: 208)
                : CGSize(width: view.bounds.width, height: 238)
            flowLayout.headerReferenceSize = size
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func editAction(_ sender: Any) {
        let viewController = R.storyboard.chat.my_stickers()!
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}

extension StickersStoreViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return listItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_store_preview, for: indexPath)!
        if indexPath.item < listItems.count {
            let item = listItems[indexPath.item]
            cell.albumItem = item
            cell.onToggle = {
                if item.isAdded {
                    StickerStore.remove(item: item)
                } else {
                    StickerStore.add(item: item)
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.sticker_banner, for: indexPath)!
        header.albumItems = bannerItems
        header.onSelected = { [weak self] item in
            self?.showStickerAlbumPreviewController(with: item)
        }
        return header
    }
    
}

extension StickersStoreViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < listItems.count else {
            return
        }
        showStickerAlbumPreviewController(with: listItems[indexPath.row])
    }
    
}

extension StickersStoreViewController {

    @objc private func reloadData() {
        if AppGroupUserDefaults.User.hasNewStickers {
            AppGroupUserDefaults.User.hasNewStickers = false
        }
        let maxBannerCount = maxBannerCount
        DispatchQueue.global().async { [weak self] in
            var bannerItems = [AlbumItem]()
            var listItems = [AlbumItem]()
            let albums = AlbumDAO.shared.getVerifiedSystemAlbums()
            let albumStickers = StickerDAO.shared.getStickers(albumIds: albums.map(\.albumId))
            for album in albums {
                guard let stickers = albumStickers[album.albumId] else {
                    continue
                }
                let item = AlbumItem(album: album, stickers: stickers)
                if !album.banner.isNilOrEmpty, bannerItems.count < maxBannerCount {
                    bannerItems.append(item)
                } else {
                    listItems.append(item)
                }
            }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.bannerItems = bannerItems
                self.listItems = listItems
                self.collectionView.reloadData()
            }
        }
    }
    
    @objc private func updateAlbumAddStatus(_ notification: Notification) {
        guard
            let albumId = notification.userInfo?[AlbumDAO.UserInfoKey.albumId] as? String,
            let isAdded = notification.userInfo?[AlbumDAO.UserInfoKey.isAdded] as? Bool
        else {
            return
        }
        if let index = bannerItems.firstIndex(where: { $0.album.albumId == albumId }) {
            bannerItems[index].isAdded = isAdded
        } else if let index = listItems.firstIndex(where: { $0.album.albumId == albumId }) {
            listItems[index].isAdded = isAdded
        }
        collectionView.reloadData()
    }
    
    private func showStickerAlbumPreviewController(with item: AlbumItem) {
        let viewController = StickersAlbumPreviewViewController.instance(with: item)
        viewController.presentAsChild(of: self)
    }
    
}
