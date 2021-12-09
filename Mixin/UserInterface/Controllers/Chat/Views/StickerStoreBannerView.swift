import UIKit
import MixinServices

class StickerStoreBannerView: UICollectionReusableView {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var onSelected: ((StickerStore.StickerInfo) -> Void)?
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_store_banner, for: indexPath)!
        if indexPath.item < stickerInfos.count, let banner = stickerInfos[indexPath.item].album.banner, let url = URL(string: banner) {
            cell.load(url: url, isStickerAdded: stickerInfos[indexPath.item].album.isAdded ?? false)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < stickerInfos.count else {
            return
        }
        onSelected?(stickerInfos[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerStoreBannerCell else {
            return
        }
        cell.startAnimating()
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerStoreBannerCell else {
            return
        }
        cell.stopAnimating()
    }
    
}
