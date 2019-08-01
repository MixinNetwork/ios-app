import UIKit

final class GalleryActivityIndicatorView: UIView {
    
    var isAnimating: Bool {
        get {
            return indicator.isAnimating
        }
        set(animate) {
            indicator.isAnimating = animate
            isHidden = !animate
        }
    }
    
    private let backgroundSize = CGSize(width: 60, height: 60)
    private let backgroundView = UIVisualEffectView(effect: .darkBlur)
    private let indicatorSize = CGSize(width: 20, height: 20)
    private let indicator = Indicator()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override var intrinsicContentSize: CGSize {
        return backgroundSize
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        backgroundView.bounds.size = backgroundSize
        backgroundView.center = center
        indicator.bounds.size = indicatorSize
        indicator.center = center
    }
    
    private func prepare() {
        backgroundView.layer.cornerRadius = backgroundSize.width / 2
        backgroundView.clipsToBounds = true
        addSubview(backgroundView)
        indicator.usesLargerStyle = false
        addSubview(indicator)
    }
    
    private final class Indicator: ActivityIndicatorView {
        
        override var lineWidth: CGFloat {
            return 3
        }
        
    }
    
}
