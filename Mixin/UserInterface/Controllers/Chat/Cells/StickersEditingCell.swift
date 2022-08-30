import UIKit
import MixinServices

class StickersEditingCell: UITableViewCell {
    
    @IBOutlet weak var stickerView: AnimatedStickerView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    
    var onDelete: (() -> Void)?
    var albumItem: AlbumItem? {
        didSet {
            if let albumItem = albumItem {
                nameLabel.text = albumItem.album.name
                countLabel.text = R.string.localizable.stickers_count(albumItem.stickers.count)
                stickerView.load(url: albumItem.album.iconUrl, persistent: true)
            } else {
                nameLabel.text = nil
                countLabel.text = nil
                stickerView.prepareForReuse()
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stickerView.prepareForReuse()
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        onDelete?()
    }
    
}
