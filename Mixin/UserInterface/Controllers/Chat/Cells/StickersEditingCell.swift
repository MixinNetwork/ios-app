import UIKit
import MixinServices

class StickersEditingCell: UITableViewCell {
    
    @IBOutlet weak var stickerImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    
    var onDeleteSticker: (() -> Void)?
    var stickerInfos: StickerStore.StickerInfo? {
        didSet {
            guard let stickerInfos = stickerInfos else {
                return
            }
            nameLabel.text = stickerInfos.album.name
            countLabel.text = R.string.localizable.sticker_count(stickerInfos.stickers.count)
            if let url = URL(string: stickerInfos.album.iconUrl) {
                let context = stickerLoadContext(category: stickerInfos.album.category)
                stickerImageView.sd_setImage(with: url, placeholderImage: nil, context: context)
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stickerImageView.sd_cancelCurrentImageLoad()
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        onDeleteSticker?()
    }
    
}
