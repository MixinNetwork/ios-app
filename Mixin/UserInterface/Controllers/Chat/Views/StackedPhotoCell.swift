import UIKit
import SDWebImage
import MixinServices

class StackedPhotoCell: UICollectionViewCell {

    static let reuseIdentifier = "StackedPhotoCell"

    var viewModel: PhotoMessageViewModel! {
        didSet {
            if let url = viewModel.attachmentURL {
                contentImageView.sd_setImage(with: url,
                                             placeholderImage: viewModel.thumbnail,
                                             context: localImageContext)
            } else {
                contentImageView.image = viewModel.thumbnail
            }
        }
    }
    
    private let contentImageWrapperView = VerticalPositioningImageView()
    private var contentImageView: UIImageView {
        return contentImageWrapperView.imageView
    }
    
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
        contentImageView.sd_cancelCurrentImageLoad()
    }
    
    private func loadSubview() {
        clipsToBounds = true
        contentView.addSubview(contentImageWrapperView)
        contentImageWrapperView.snp.makeEdgesEqualToSuperview()
    }
    
}
