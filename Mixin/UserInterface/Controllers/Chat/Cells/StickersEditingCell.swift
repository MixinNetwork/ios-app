import UIKit
import MixinServices

class StickersEditingCell: UITableViewCell {
    
    @IBOutlet weak var stickerImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    
    var onDelete: (() -> Void)?
    var albumItem: AlbumItem? {
        didSet {
            if let albumItem = albumItem {
                nameLabel.text = albumItem.album.name
                countLabel.text = R.string.localizable.stickers_count(albumItem.stickers.count)
                if let url = URL(string: albumItem.album.iconUrl) {
                    stickerImageView.sd_setImage(with: url, placeholderImage: nil, context: persistentStickerContext)
                }
            } else {
                nameLabel.text = nil
                countLabel.text = nil
                stickerImageView.sd_cancelCurrentImageLoad()
                stickerImageView.image = nil
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stickerImageView.sd_cancelCurrentImageLoad()
        stickerImageView.image = nil
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        onDelete?()
    }
    
}
