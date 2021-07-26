import UIKit
import MixinServices

class StickersStoreViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    var stickerStoreItems = [StickerStoreItem]()
    
    class func instance() -> UIViewController {
        R.storyboard.chat.sticker_store()!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //TODO: remove mock
        let albums = AlbumDAO.shared.getAlbums()
        stickerStoreItems = albums.map({ StickerStoreItem(album: $0, stickers: StickerDAO.shared.getStickers(albumId: $0.albumId)) })
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        flowLayout.itemSize = CGSize(width: view.bounds.width, height: 102)
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func editAction(_ sender: Any) {
        let viewController = StickersEditingViewController.instance()
        viewController.stickerStoreItems = stickerStoreItems
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}

extension StickersStoreViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickerStoreItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_store_preview, for: indexPath)!
        if indexPath.item < stickerStoreItems.count {
            cell.stickerStoreItem = stickerStoreItems[indexPath.row]
            cell.onAddSticker = {
                
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.sticker_banner, for: indexPath)!
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item < stickerStoreItems.count {
            let viewController = StickersAlbumPreviewViewController.instance()
            viewController.stickerStoreItem = stickerStoreItems[indexPath.row]
            viewController.presentAsChild(of: self)
        }
    }
    
}
