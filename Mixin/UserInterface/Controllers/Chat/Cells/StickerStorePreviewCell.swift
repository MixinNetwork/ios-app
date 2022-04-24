import UIKit
import MixinServices

class StickerStorePreviewCell: UICollectionViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var layout: UICollectionViewFlowLayout!
    
    @IBOutlet weak var collectionViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewTrailingConstraint: NSLayoutConstraint!
    
    var onToggle: (() -> Void)?
    var albumItem: AlbumItem? {
        didSet {
            if let albumItem = albumItem {
                nameLabel.text = albumItem.album.name
                if albumItem.isAdded {
                    addButton.setTitle(R.string.localizable.added(), for: .normal)
                    addButton.backgroundColor = R.color.sticker_button_background_disabled()
                    addButton.setTitleColor(R.color.sticker_button_text_disabled(), for: .normal)
                } else {
                    addButton.setTitle(R.string.localizable.add(), for: .normal)
                    addButton.backgroundColor = R.color.theme()
                    addButton.setTitleColor(.white, for: .normal)
                }
            } else {
                nameLabel.text = nil
                addButton.setTitle(nil, for: .normal)
            }
            collectionView.reloadData()
        }
    }
    
    private var maxStickerPreviewCount = 4
    
    @IBAction func stickerAction(_ sender: Any) {
        onToggle?()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let margin: CGFloat = ScreenWidth.current <= .short ? 10 : 20
        collectionViewLeadingConstraint.constant = margin
        collectionViewTrailingConstraint.constant = margin
        let totalWidth = UIScreen.main.bounds.width - 2 * margin
        let itemWidth = layout.itemSize.width + layout.minimumLineSpacing
        maxStickerPreviewCount = Int(totalWidth / itemWidth)
    }
    
}

extension StickerStorePreviewCell: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let albumItem = albumItem else {
            return 0
        }
        return min(maxStickerPreviewCount, albumItem.stickers.count)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_preview, for: indexPath)!
        if let albumItem = albumItem, indexPath.item < albumItem.stickers.count {
            cell.stickerView.load(sticker: albumItem.stickers[indexPath.item])
            cell.stickerView.startAnimating()
        }
        return cell
    }
    
}
