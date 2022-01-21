import UIKit

class PhotoInputGridCell: UICollectionViewCell {
    
    @IBOutlet weak var imageWrapperView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var mediaTypeView: MediaTypeOverlayView!
    @IBOutlet weak var badge: BadgeView!
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
        badge.cornerRadius = 10
        badge.textColor = .white
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPathIfNeeded()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        overlayView.isHidden = true
    }
    
    func updateSelectedIndex(_ index: Int?) {
        if let index = index {
            badge.text = "\(index + 1)"
            badge.borderWidth = 0
            badge.borderColor = .clear
            badge.badgeColor = .theme
            overlayView.isHidden = false
        } else {
            badge.text = nil
            badge.borderWidth = 1
            badge.borderColor = .white
            badge.badgeColor = .black.withAlphaComponent(0.16)
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
