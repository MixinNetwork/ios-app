import UIKit
import MixinServices

class StickersEditingCell: UITableViewCell {
    
    @IBOutlet weak var stickerImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    
    var onDelete: (() -> Void)?
    var stickerInfo: StickerStore.StickerInfo? {
        didSet {
            guard let stickerInfos = stickerInfo else {
                return
            }
            nameLabel.text = stickerInfos.album.name
            countLabel.text = R.string.localizable.sticker_count(stickerInfos.stickers.count)
            if let url = URL(string: stickerInfos.album.iconUrl) {
                stickerImageView.sd_setImage(with: url, placeholderImage: nil, context: persistentStickerContext)
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stickerImageView.sd_cancelCurrentImageLoad()
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        onDelete?()
    }
    
}
