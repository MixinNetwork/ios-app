import UIKit

class DragDownIndicator: UIView {
    
    let imageView: UIImageView = {
        let imageView = UIImageView()
        let image = R.image.ic_arrow_down()!
        imageView.image = image
        imageView.bounds.size = image.size
        return imageView
    }()
    
    var isHighlighted = false {
        didSet {
            guard isHighlighted != oldValue else {
                return
            }
            let t = isHighlighted ? CGAffineTransform(scaleX: 1.5, y: 1.5) : .identity
            UIView.animate(withDuration: 0.2, delay: 0, options: .beginFromCurrentState, animations: {
                self.imageView.transform = t
            }, completion: nil)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addSubview(imageView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    }
    
}
