import UIKit

class PhotoInputGridCell: UICollectionViewCell {
    
    @IBOutlet weak var imageWrapperView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var sendLabel: UILabel!
    @IBOutlet weak var fileTypeWrapperView: UIView!
    @IBOutlet weak var gifFileTypeView: UILabel!
    @IBOutlet weak var videoTypeView: UIStackView!
    @IBOutlet weak var videoDurationLabel: UILabel!
    
    let visualEffectView = UIVisualEffectView(effect: nil)
    let cornerRadius: CGFloat = 8
    
    var identifier: String?
    
    private var lastImageWrapperFrame = CGRect.zero
    
    override var isSelected: Bool {
        didSet {
            sendLabel.alpha = isSelected ? 1 : 0
            visualEffectView.effect = isSelected ? .darkBlur : nil
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        updateShadowPathIfNeeded()
        contentView.layer.shadowColor = UIColor(rgbValue: 0xC3C3C3).cgColor
        contentView.layer.shadowOpacity = 0.29
        contentView.layer.shadowRadius = 5
        visualEffectView.frame = imageWrapperView.bounds
        visualEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageWrapperView.insertSubview(visualEffectView, belowSubview: sendLabel)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPathIfNeeded()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
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
