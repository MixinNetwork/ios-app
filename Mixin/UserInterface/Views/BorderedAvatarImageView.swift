import UIKit

class BorderedAvatarImageView: AvatarImageView {
    
    let backgroundView = UIView()
    
    var borderWidth: CGFloat = 2 {
        didSet {
            setNeedsLayout()
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
    
    override func layout(imageView: UIImageView) {
        let backgroundLength = min(bounds.width, bounds.height)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        backgroundView.frame.size = CGSize(width: backgroundLength, height: backgroundLength)
        backgroundView.center = center
        backgroundView.layer.cornerRadius = backgroundLength / 2
        let length = backgroundLength - borderWidth * 2
        imageView.bounds.size = CGSize(width: length, height: length)
        imageView.center = center
    }
    
    private func prepare() {
        backgroundView.backgroundColor = .background
        backgroundView.clipsToBounds = true
        insertSubview(backgroundView, at: 0)
    }
    
}
