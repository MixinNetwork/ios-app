import UIKit
import YYImage
import SDWebImage

class VerticalPositioningImageView: UIView {
    
    enum Position {
        case relativeOffset(CGFloat)
        case center
    }
    
    var position = Position.center {
        didSet {
            setNeedsLayout()
        }
    }
    
    var image: UIImage? {
        get {
            return imageView.image
        }
        set {
            aspectRatio = newValue?.size ?? .zero
            imageView.image = newValue
            setNeedsLayout()
        }
    }
    
    var aspectRatio = CGSize.zero
    
    private let imageView = YYAnimatedImageView()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if aspectRatio.width <= 1 {
            aspectRatio = CGSize(width: 1, height: 1)
        }
        switch position {
        case .center:
            imageView.frame.size = CGSize(width: bounds.width, height: bounds.width / aspectRatio.width * aspectRatio.height)
            imageView.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        case .relativeOffset(let offset):
            imageView.frame.size = CGSize(width: bounds.width, height: bounds.width * aspectRatio.height / aspectRatio.width)
            let y = offset * imageView.bounds.size.height
            imageView.frame.origin = CGPoint(x: 0, y: y)
        }
    }
    
    func set(thumbnail: UIImage?, ratio: CGSize) {
        imageView.contentMode = .scaleToFill
        imageView.image = thumbnail
        aspectRatio = ratio
        setNeedsLayout()
    }
    
    func setImage(with url: URL, placeholder: UIImage?, ratio: CGSize) {
        aspectRatio = ratio
        imageView.contentMode = .scaleToFill
        imageView.sd_setImage(with: url, placeholderImage: placeholder, options: []) { (_, _, _, _) in
            self.imageView.contentMode = .scaleAspectFill
            self.setNeedsLayout()
        }
        setNeedsLayout()
    }
    
    func cancelCurrentImageLoad() {
        imageView.sd_cancelCurrentImageLoad()
    }
    
    private func prepare() {
        addSubview(imageView)
        clipsToBounds = true
    }
    
}
