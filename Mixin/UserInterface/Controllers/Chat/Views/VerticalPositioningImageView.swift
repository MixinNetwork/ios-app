import UIKit
import SDWebImage

class VerticalPositioningImageView: UIView {
    
    enum Position {
        case relativeOffset(CGFloat)
        case center
    }
    
    let imageView = SDAnimatedImageView()
    
    var position = Position.center {
        didSet {
            setNeedsLayout()
        }
    }
    
    var aspectRatio = CGSize.zero {
        didSet {
            if aspectRatio != oldValue {
                setNeedsLayout()
            }
        }
    }
    
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
    
    private func prepare() {
        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)
        clipsToBounds = true
    }
    
}
