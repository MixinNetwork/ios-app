import UIKit
import MixinServices

class StickersStoreViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    private var bannerItems = [StickerStoreItem]()
    private var listItems = [StickerStoreItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        StickersStoreManager.shared().loadStoreStickers { bannerItems, listItems in
            self.bannerItems = bannerItems
            self.listItems = listItems
            self.collectionView.reloadData()
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(syncStickerAlbums),
                                               name: AppGroupUserDefaults.User.stickerAlbumIdsDidChangeNotification,
                                               object: nil)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        flowLayout.itemSize = CGSize(width: view.bounds.width, height: 104)
        if bannerItems.isEmpty {
            flowLayout.headerReferenceSize = .zero
        } else {
            flowLayout.headerReferenceSize = ScreenWidth.current < .medium ? CGSize(width: view.bounds.width, height: 208) : CGSize(width: view.bounds.width, height: 238)
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
            let item = listItems[indexPath.row]
            cell.stickerStoreItem = item
            cell.onStickerOperation = {
                StickersStoreManager.shared().handleStickerOperation(with: item)
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.sticker_banner, for: indexPath)!
        header.stickerStoreItems = bannerItems
        header.onSelectItem = { [weak self] item in
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
    
    @objc private func syncStickerAlbums() {
        guard let albumIds = AppGroupUserDefaults.User.stickerAblums else {
            return
        }
        for (index, item) in bannerItems.enumerated() {
            bannerItems[index].isAdded = albumIds.contains(item.album.albumId)
        }
        for (index, item) in listItems.enumerated() {
            listItems[index].isAdded = albumIds.contains(item.album.albumId)
        }
        collectionView.reloadData()
    }
    
    private func showStickerAlbumPreviewController(with item: StickerStoreItem) {
        let viewController = StickersAlbumPreviewViewController.instance(with: item)
        viewController.presentAsChild(of: self)
    }
    
}
