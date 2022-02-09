import UIKit
import MixinServices

class StickersStoreViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    private let queue = DispatchQueue(label:"one.mixin.messenger.StickersStoreViewController.fetchAlbums", attributes: .concurrent)
    private let maxBannerCount = 3

    private var bannerItems = [AlbumItem]()
    private var listItems = [AlbumItem]()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadData()
        reloadRemoteAlbums()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateAlbumAddStatus(_:)),
                                               name: AlbumDAO.addedAlbumsDidChangeNotification,
                                               object: nil)
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

    private func reloadData() {
        let maxBannerCount = maxBannerCount
        DispatchQueue.global().async { [weak self] in
            var bannerItems = [AlbumItem]()
            var listItems = [AlbumItem]()
            let albums = AlbumDAO.shared.getNonPersonalAlbums()
            albums.forEach { album in
                let stickers = StickerDAO.shared.getStickers(albumId: album.albumId)
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
    
    private func reloadRemoteAlbums() {
        let group = DispatchGroup()
        group.enter()
        queue.async(group: group) { [weak self] in
            guard let self = self else {
                return
            }
            let albumsUpdatedAt = AlbumDAO.shared.getAlbumsUpdatedAt()
            switch StickerAPI.albums() {
            case let .success (albums):
                let newAlbums = albums.filter { albumsUpdatedAt[$0.albumId] != $0.updatedAt }
                for album in newAlbums {
                    group.enter()
                    self.queue.async(group: group) {
                        switch StickerAPI.stickers (albumId: album.albumId) {
                        case let .success (stickers):
                            group.enter()
                            AlbumDAO.shared.insertOrUpdateAblum(album: album, completion: group.leave)
                            group.enter()
                            _ = StickerDAO.shared.insertOrUpdateStickers(stickers: stickers, albumId: album.albumId, completion: group.leave)
                        case let .failure(error):
                            reporter.report(error: error)
                        }
                        group.leave()
                    }
                }
            case let .failure(error):
                reporter.report(error: error)
            }
            group.leave()
        }
        group.notify(queue: .main) { [weak self] in
            guard let self = self else {
                return
            }
            self.reloadData()
            AppGroupUserDefaults.User.stickerRefreshDate = Date()
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
