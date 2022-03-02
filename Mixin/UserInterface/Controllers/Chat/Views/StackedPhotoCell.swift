import UIKit
import SDWebImage
import MixinServices

class StackedPhotoCell: UICollectionViewCell {
    
    static let reuseIdentifier = "cell_identifier_stacked_photo_cell"
    
    var viewModel: PhotoMessageViewModel! {
        didSet {
            if let url = viewModel.attachmentURL {
                imageView.sd_setImage(with: url,
                                      placeholderImage: viewModel.thumbnail,
                                      context: localImageContext)
            } else {
                imageView.image = viewModel.thumbnail
            }
        }
    }
    
    private var imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubview()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubview()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
    }
    
    func updateAnchorPoint() {
        layer.anchorPoint = CGPoint(x: 1, y: 1)
        let centerX = 0.5 * bounds.width + center.x
        let centerY = 0.5 * bounds.height + center.y
        center = CGPoint(x: centerX, y: centerY)
    }
    
    private func loadSubview() {
        layer.cornerRadius = 13
        clipsToBounds = true
        contentView.addSubview(imageView)
        imageView.snp.makeEdgesEqualToSuperview()
        imageView.layer.shouldRasterize = true
        imageView.layer.allowsEdgeAntialiasing = true
        imageView.contentMode = .scaleAspectFill
    }
    
}
