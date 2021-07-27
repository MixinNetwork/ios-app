import UIKit
import MixinServices

class StickersStoreViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    private var stickerStoreItems = [StickerStoreItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //TODO: remove mock
        let albums = AlbumDAO.shared.getAlbums()
        stickerStoreItems = albums.map({ StickerStoreItem(album: $0, stickers: StickerDAO.shared.getStickers(albumId: $0.albumId)) })
        collectionView.reloadData()
        //TODO: update banner
        //flowLayout.headerReferenceSize = .zero
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(syncStickers),
                                               name: AppGroupUserDefaults.User.stickerIdsDidChangeNotification,
                                               object: nil)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        flowLayout.itemSize = CGSize(width: view.bounds.width, height: 102)
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func editAction(_ sender: Any) {
        let viewController = R.storyboard.chat.my_stickers()!
        viewController.stickerStoreItems = stickerStoreItems
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}

extension StickersStoreViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickerStoreItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_store_preview, for: indexPath)!
        if indexPath.item < stickerStoreItems.count {
            cell.stickerStoreItem = stickerStoreItems[indexPath.row]
            cell.onStickerAction = {
                
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.sticker_banner, for: indexPath)!
        header.stickerStoreItems = Array(stickerStoreItems.prefix(3))
        header.onSelectItem = { item in
            self.showStickerAlbumPreviewController(with: item)
        }
        return header
    }
    
}

extension StickersStoreViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < stickerStoreItems.count else {
            return
        }
        showStickerAlbumPreviewController(with: stickerStoreItems[indexPath.row])
    }
    
}

extension StickersStoreViewController {
    
    @objc private func syncStickers() {
        let stickers = AppGroupUserDefaults.User.stickers
        for index in stickerStoreItems.indices {
            var item = stickerStoreItems[index]
            item.isAdded = stickers.contains(item.album.albumId)
        }
        collectionView.reloadData()
    }
    
    private func showStickerAlbumPreviewController(with item: StickerStoreItem) {
        let viewController = StickersAlbumPreviewViewController.instance()
        viewController.stickerStoreItem = item
        viewController.presentAsChild(of: self)
    }
    
}
