import UIKit
import MixinServices

class StickerStoreBannerView: UICollectionReusableView {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var onSelectItem: ((StickerStoreItem) -> Void)?
    var stickerStoreItems: [StickerStoreItem] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    
}

extension StickerStoreBannerView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickerStoreItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_preview, for: indexPath)!
        if indexPath.item < stickerStoreItems.count,
           let banner = stickerStoreItems[indexPath.item].album.banner,
           let url = URL(string: banner) {
            cell.stickerView.load(imageURL: url, contentMode: .scaleAspectFill)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < stickerStoreItems.count else {
            return
        }
        onSelectItem?(stickerStoreItems[indexPath.item])
    }
    
}
