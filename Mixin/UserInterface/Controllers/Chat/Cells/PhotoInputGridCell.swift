import UIKit

class PhotoInputGridCell: UICollectionViewCell {
    
    @IBOutlet weak var imageWrapperView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var mediaTypeView: MediaTypeOverlayView!
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet weak var indexLabel: UILabel!
    @IBOutlet weak var overlayView: UIView!
    
    let cornerRadius: CGFloat = 8
    
    var identifier: String?
    
    private var lastImageWrapperFrame = CGRect.zero
    
    override func awakeFromNib() {
        super.awakeFromNib()
        updateShadowPathIfNeeded()
        contentView.layer.shadowColor = UIColor.shadow.cgColor
        contentView.layer.shadowOpacity = 0.29
        contentView.layer.shadowRadius = 5
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPathIfNeeded()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
    
    func updateBadge(with index: Int?) {
        if let index = index {
            indexLabel.text = "\(index + 1)"
            statusImageView.backgroundColor = .theme
            statusImageView.image = nil
            overlayView.isHidden = false
        } else {
            indexLabel.text = nil
            statusImageView.backgroundColor = .clear
            statusImageView.image = R.image.ic_photo_unselected_narrow()
            overlayView.isHidden = true
        }
    }
    
    private func updateShadowPathIfNeeded() {
        guard imageWrapperView.frame != lastImageWrapperFrame else {
            return
        }
        var rect = imageWrapperView.frame
        rect.origin.y += 6
        let path = CGPath(roundedRect: rect,
                          cornerWidth: cornerRadius,
                          cornerHeight: cornerRadius,
                          transform: nil)
        contentView.layer.shadowPath = path
        lastImageWrapperFrame = imageWrapperView.frame
    }
    
}
