import UIKit

protocol ClipThumbnailCellDelegate {
    func clipThumbnailCellDidSelectClose(_ cell: ClipThumbnailCell)
}

class ClipThumbnailCell: UICollectionViewCell {
    
    @IBOutlet weak var contentWrapperView: UIView!
    @IBOutlet weak var appAvatarImageView: AvatarImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var thumbnailWrapperView: UIView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    
    var delegate: ClipThumbnailCellDelegate?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let image = thumbnailImageView.image {
            let ratio = image.size.width / image.size.height
            let size = CGSize(width: thumbnailWrapperView.frame.width,
                              height: thumbnailWrapperView.frame.width / ratio)
            thumbnailImageView.frame = CGRect(origin: .zero, size: size)
        }
    }
    
    @IBAction func close(_ sender: Any) {
        delegate?.clipThumbnailCellDidSelectClose(self)
    }
    
}
