import UIKit
import MixinServices

class FavoriteStickerCell: UICollectionViewCell {
    
    @IBOutlet weak var stickerView: AnimatedStickerView!
    @IBOutlet weak var selectionMaskView: UIView!
    @IBOutlet weak var selectionImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
        stickerView.autoPlayAnimatedImage = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stickerView.prepareForReuse()
    }
    
    override var isSelected: Bool {
        didSet {
            guard !selectionImageView.isHidden else {
                return
            }
            selectionImageView.image = isSelected
                ? R.image.ic_member_selected()
                : R.image.ic_sticker_normal()
            selectionMaskView.isHidden = !isSelected
        }
    }
    
    func render(sticker: StickerItem, isDeleteStickers: Bool) {
        selectionImageView.isHidden = !isDeleteStickers
        stickerView.load(sticker: sticker)
    }
    
}
