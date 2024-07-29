import UIKit

final class CircularProgressView: UIView {
    
    var trackColor: UIColor = R.color.button_background_disabled()! {
        didSet {
            trackLayer.strokeColor = trackColor.resolvedColor(with: traitCollection).cgColor
        }
    }
    
    var progressColor: UIColor = R.color.icon_tint()! {
        didSet {
            progressLayer.strokeColor = progressColor.resolvedColor(with: traitCollection).cgColor
        }
    }
    
    var lineWidth: CGFloat = 2 {
        didSet {
            trackLayer.lineWidth = lineWidth
            progressLayer.lineWidth = lineWidth
        }
    }
    
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    
    private var lastLayoutBounds: CGRect?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadSubviews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds != lastLayoutBounds {
            let path = UIBezierPath(
                arcCenter: CGPoint(x: bounds.size.width / 2, y: bounds.size.height / 2),
                radius: (bounds.size.width - lineWidth) / 2,
                startAngle: -(1 / 2) * .pi,
                endAngle: (3 / 2) * .pi, clockwise: true
            ).cgPath
            trackLayer.frame = bounds
            trackLayer.path = path
            progressLayer.frame = bounds
            progressLayer.path = path
            lastLayoutBounds = bounds
        }
    }
    
    // The `progress` must be in the range [0,1]
    func setProgress(_ progress: Double, animationDuration: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeEnd))
        animation.duration = animationDuration
        animation.fromValue = progressLayer.strokeEnd
        animation.toValue = progress
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        progressLayer.strokeEnd = progress
        progressLayer.add(animation, forKey: "progress")
    }
    
    private func loadSubviews() {
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = trackColor.resolvedColor(with: traitCollection).cgColor
        trackLayer.lineWidth = lineWidth
        layer.addSublayer(trackLayer)
        
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = progressColor.resolvedColor(with: traitCollection).cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)
    }
    
}
