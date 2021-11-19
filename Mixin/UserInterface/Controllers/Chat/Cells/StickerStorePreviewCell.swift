import UIKit
import MixinServices

class StickerStorePreviewCell: UICollectionViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var collectionViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewTrailingConstraint: NSLayoutConstraint!
    
    var onStickerOperation: (() -> Void)?
    var stickerInfo: StickerStore.StickerInfo? {
        didSet {
            guard let stickerInfo = stickerInfo else {
                return
            }
            nameLabel.text = stickerInfo.album.name
            if stickerInfo.isAdded {
                addButton.setTitle(R.string.localizable.sticker_store_added(), for: .normal)
                addButton.backgroundColor = R.color.sticker_button_background_disabled()
                addButton.setTitleColor(R.color.sticker_button_text_disabled(), for: .normal)
            } else {
                addButton.setTitle(R.string.localizable.sticker_store_add(), for: .normal)
                addButton.backgroundColor = R.color.theme()
                addButton.setTitleColor(.white, for: .normal)
            }
            collectionView.reloadData()
        }
    }
    private let cellCountPerRow = 4
    
    @IBAction func stickerAction(_ sender: Any) {
        onStickerOperation?()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let margin: CGFloat = ScreenWidth.current <= .short ? 10 : 20
        collectionViewLeadingConstraint.constant = margin
        collectionViewTrailingConstraint.constant = margin
    }
    
}

extension StickerStorePreviewCell: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let stickerInfo = stickerInfo else {
            return 0
        }
        return min(cellCountPerRow, stickerInfo.stickers.count)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_preview, for: indexPath)!
        if let stickerInfo = stickerInfo, indexPath.item < stickerInfo.stickers.count {
            cell.stickerView.load(sticker: stickerInfo.stickers[indexPath.item])
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
