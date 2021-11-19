import UIKit
import MixinServices

class StickerStoreBannerView: UICollectionReusableView {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var onSelectSticker: ((StickerStore.StickerInfo) -> Void)?
    var stickerInfos: [StickerStore.StickerInfo] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    
}

extension StickerStoreBannerView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickerInfos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_preview, for: indexPath)!
        if indexPath.item < stickerInfos.count,  let banner = stickerInfos[indexPath.item].album.banner, let url = URL(string: banner) {
            cell.stickerView.load(imageURL: url, contentMode: .scaleAspectFill)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < stickerInfos.count else {
            return
        }
        onSelectSticker?(stickerInfos[indexPath.item])
    }
    
}
