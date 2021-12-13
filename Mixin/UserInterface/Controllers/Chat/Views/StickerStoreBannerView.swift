import UIKit
import MixinServices

class StickerStoreBannerView: UICollectionReusableView {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var layout: StickersStoreBannerFlowLayout!
    
    var onSelected: ((AlbumItem) -> Void)?
    var albumItems: [AlbumItem] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.decelerationRate = .fast
        layout.minimumLineSpacing = 6
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layout.itemSize = ScreenWidth.current <= .short
            ? CGSize(width: 273, height: 170)
            : CGSize(width: 320, height: 200)
        let horizontalInset = floor((UIScreen.main.bounds.width - layout.itemSize.width) / 2)
        layout.sectionInset = UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
    }
    
}

extension StickerStoreBannerView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return albumItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_store_banner, for: indexPath)!
        if indexPath.item < albumItems.count, let banner = albumItems[indexPath.item].album.banner, let url = URL(string: banner) {
            cell.load(url: url, isStickerAdded: albumItems[indexPath.item].isAdded)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < albumItems.count else {
            return
        }
        onSelected?(albumItems[indexPath.item])
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
