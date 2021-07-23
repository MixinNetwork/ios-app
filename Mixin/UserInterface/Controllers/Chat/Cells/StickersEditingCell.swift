import UIKit
import MixinServices

class StickersEditingCell: UITableViewCell {
    
    @IBOutlet weak var stickerImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    
    var onDeleteSticker: (() -> Void)?
    var stickerStoreItem: StickerStoreItem! {
        didSet {
            nameLabel.text = stickerStoreItem.album.name
            countLabel.text = Localized.STICKER_COUNT(count: stickerStoreItem.stickers.count)
            if let url = URL(string: stickerStoreItem.album.iconUrl) {
                let context = stickerLoadContext(category: stickerStoreItem.album.category)
                stickerImageView.sd_setImage(with: url, placeholderImage: nil, context: context)
            }
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stickerImageView.sd_cancelCurrentImageLoad()
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        onDeleteSticker?()
    }
    
}
