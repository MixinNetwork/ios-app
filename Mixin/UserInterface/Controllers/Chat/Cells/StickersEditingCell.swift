import UIKit
import MixinServices

class StickersEditingCell: UITableViewCell {
    
    @IBOutlet weak var stickerImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    
    var onDelete: (() -> Void)?
    var albumItem: AlbumItem? {
        didSet {
            guard let albumItem = albumItem else {
                return
            }
            nameLabel.text = albumItem.album.name
            countLabel.text = R.string.localizable.sticker_count(albumItem.stickers.count)
            if let url = URL(string: albumItem.album.iconUrl) {
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
