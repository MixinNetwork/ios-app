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
        
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
}

extension StickerStoreBannerView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickerStoreItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_preview, for: indexPath)!
        if indexPath.item < stickerStoreItems.count, let url = URL(string: stickerStoreItems[indexPath.item].album.iconUrl) {
            cell.stickerView.load(imageURL: url, contentMode: .scaleAspectFill)
        }
        cell.backgroundColor = UIColor(red: .random(in: 0...1),
                                       green: .random(in: 0...1),
                                       blue: .random(in: 0...1),
                                       alpha: 1.0)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < stickerStoreItems.count else {
            return
        }
        onSelectItem?(stickerStoreItems[indexPath.item])
    }
    
}
