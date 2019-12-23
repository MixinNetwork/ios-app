import UIKit
import MixinServices

class FavoriteStickersViewController: StickersViewController {
    
    init(index: Int) {
        super.init(nibName: nil, bundle: nil)
        self.index = index
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteStickerDidChange(_:)), name: .FavoriteStickersDidChange, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func favoriteStickerDidChange(_ notification: Notification) {
        DispatchQueue.global().async {
            let stickers = StickerDAO.shared.getFavoriteStickers()
            DispatchQueue.main.async {
                self.stickers = stickers
                self.collectionView.reloadData()
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickers.count + 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! AnimatedImageCollectionViewCell
        if indexPath.row == 0 {
            cell.imageView.image = R.image.ic_sticker_add()
        } else {
            let sticker = stickers[indexPath.row - 1]
            if let url = URL(string: sticker.assetUrl) {
                cell.imageView.sd_setImage(with: url, placeholderImage: nil, context: sticker.imageLoadContext)
            }
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            let vc = StickerManagerViewController.instance()
            navigationController?.pushViewController(vc, animated: true)
        } else {
            send(sticker: stickers[indexPath.row - 1])
        }
    }
    
}
