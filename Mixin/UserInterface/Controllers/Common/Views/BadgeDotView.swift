import UIKit

final class BadgeDotView: UIView {
    
    private let dotLayer = CALayer()
    private let dotSize = CGSize(width: 8, height: 8)
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: 12, height: 12)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSublayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSublayer()
    }
    
    private func loadSublayer() {
        layer.masksToBounds = true
        dotLayer.backgroundColor = R.color.error_red()!.cgColor
        dotLayer.cornerRadius = dotSize.width / 2
        dotLayer.frame.size = dotSize
        layer.addSublayer(dotLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        dotLayer.position = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    }
    
}
