import UIKit
import MixinServices

class StickersStoreViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    private var bannerStickerInfos = [StickerStore.StickerInfo]()
    private var listStickerInfos = [StickerStore.StickerInfo]()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        StickerStore.loadStoreStickers { bannerStickerInfos, listStickerInfos in
            self.bannerStickerInfos = bannerStickerInfos
            self.listStickerInfos = listStickerInfos
            self.collectionView.reloadData()
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateAlbumAddStatus(_:)),
                                               name: AlbumDAO.addedAlbumsDidChangeNotification,
                                               object: nil)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        flowLayout.itemSize = CGSize(width: view.bounds.width, height: 104)
        if bannerStickerInfos.isEmpty {
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
        return listStickerInfos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_store_preview, for: indexPath)!
        if indexPath.item < listStickerInfos.count {
            let stickerInfo = listStickerInfos[indexPath.item]
            cell.stickerInfo = stickerInfo
            cell.onToggle = {
                if stickerInfo.isAdded {
                    StickerStore.remove(stickers: stickerInfo)
                } else {
                    StickerStore.add(stickers: stickerInfo)
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.sticker_banner, for: indexPath)!
        header.stickerInfos = bannerStickerInfos
        header.onSelected = { [weak self] stickerInfo in
            self?.showStickerAlbumPreviewController(with: stickerInfo)
        }
        return header
    }
    
}

extension StickersStoreViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < listStickerInfos.count else {
            return
        }
        showStickerAlbumPreviewController(with: listStickerInfos[indexPath.row])
    }
    
}

extension StickersStoreViewController {

    @objc private func updateAlbumAddStatus(_ notification: Notification) {
        guard
            let albumId = notification.userInfo?[AlbumDAO.UserInfoKey.albumId] as? String,
            let isAdded = notification.userInfo?[AlbumDAO.UserInfoKey.isAdded] as? Bool
        else {
            return
        }
        if let index = bannerStickerInfos.firstIndex(where: { $0.album.albumId == albumId }) {
            bannerStickerInfos[index].isAdded = isAdded
        } else if let index = listStickerInfos.firstIndex(where: { $0.album.albumId == albumId }) {
            listStickerInfos[index].isAdded = isAdded
        }
        collectionView.reloadData()
    }
    
    private func showStickerAlbumPreviewController(with stickerInfo: StickerStore.StickerInfo) {
        let viewController = StickersAlbumPreviewViewController.instance(with: stickerInfo)
        viewController.presentAsChild(of: self)
    }
    
}
