import UIKit

class HomeTitleButton: UIButton {
    
    private lazy var dotView: UIView = {
        let view = UIView()
        view.frame.size = CGSize(width: 8, height: 8)
        view.clipsToBounds = true
        view.layer.cornerRadius = 4
        view.backgroundColor = .theme
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        addSubview(view)
        return view
    }()
    
    var showsTopRightDot = false {
        didSet {
            dotView.isHidden = !showsTopRightDot
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let titleLabel = titleLabel else {
            dotView.center = CGPoint(x: bounds.maxX - 4, y: bounds.minY - 4)
            return
        }
        var origin = CGPoint(x: titleLabel.frame.maxX, y: titleLabel.frame.origin.y)
        origin.x = min(origin.x, bounds.maxX - 4)
        dotView.frame.origin = origin
    }
    
}
