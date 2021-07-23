import UIKit
import MixinServices

class StickerStorePreviewCell: UICollectionViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var onAddSticker: (() -> Void)?
    var stickerStoreItem: StickerStoreItem! {
        didSet {
            nameLabel.text = stickerStoreItem.album.name
            collectionView.reloadData()
        }
    }
    
    private let cellCountPerRow = 4
    
    @IBAction func addAction(_ sender: Any) {
        onAddSticker?()
    }
    
}

extension StickerStorePreviewCell: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(cellCountPerRow, stickerStoreItem.stickers.count)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_preview, for: indexPath)!
        if indexPath.item < stickerStoreItem.stickers.count {
            cell.stickerView.load(sticker: stickerStoreItem.stickers[indexPath.item])
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerPreviewCell else {
            return
        }
        cell.stickerView.startAnimating()
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerPreviewCell else {
            return
        }
        cell.stickerView.stopAnimating()
    }
    
}
