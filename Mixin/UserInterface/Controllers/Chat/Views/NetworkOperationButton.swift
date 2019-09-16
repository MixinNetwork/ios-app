import UIKit

class NetworkOperationButton: UIButton {
    
    enum Style {
        case finished(showPlayIcon: Bool)
        case upload
        case download
        case expired
        case busy(progress: Double)
        
        var isBusy: Bool {
            if case .busy(_) = self {
                return true
            } else {
                return false
            }
        }
    }
    
    lazy var backgroundView: UIView = {
        let view = type(of: self).makeBackgroundView()
        view.tintColor = indicatorColor
        return view
    }()
    
    override var intrinsicContentSize: CGSize {
        return backgroundSize
    }
    
    var style = Style.finished(showPlayIcon: false) {
        didSet {
            update(with: style, oldStyle: oldValue)
        }
    }
    
    var backgroundSize: CGSize {
        return CGSize(width: 38, height: 38)
    }
    
    var iconSet: NetworkOperationIconSet.Type {
        return NormalNetworkOperationIconSet.self
    }
    
    var indicatorLineWidth: CGFloat {
        return 1.5
    }
    
    var indicatorColor: UIColor {
        return UIColor(displayP3RgbValue: 0x3D75E3)
    }
    
    private enum AnimationKey {
        static let rotation = "rotation"
        static let strokeEnd = "strokeEnd"
    }
    
    private let minProgress: Double = 0.05
    private let maxProgress: Double = 0.95
    
    private lazy var indicatorLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = indicatorColor.cgColor
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.lineWidth = indicatorLineWidth
        layer.lineCap = .round
        layer.path = UIBezierPath(arcCenter: .zero,
                                  radius: indicatorLength / 2,
                                  startAngle: -.pi / 2,
                                  endAngle: 3 / 4 * .pi,
                                  clockwise: true).cgPath
        return layer
    }()
    
    private var indicatorCenter = CGPoint.zero
    
    private var indicatorLength: CGFloat {
        return backgroundSize.width - indicatorLineWidth
    }
    
    private var minStrokeEnd: CGFloat {
        return CGFloat(1 * minProgress)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    class func makeBackgroundView() -> UIView {
        let view = UIImageView(image: R.image.ic_network_op_background_legacy())
        view.contentMode = .center
        return view
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.bounds.size = backgroundSize
        backgroundView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        sendSubviewToBack(backgroundView)
        if style.isBusy {
            indicatorCenter = CGPoint(x: indicatorLength / 2, y: indicatorLength / 2)
            indicatorLayer.frame = CGRect(x: bounds.midX - indicatorLength / 2,
                                          y: bounds.midY - indicatorLength / 2,
                                          width: indicatorLength,
                                          height: indicatorLength)
        }
    }
    
    func update(with newStyle: Style, oldStyle: Style) {
        if oldStyle.isBusy && !newStyle.isBusy {
            indicatorLayer.removeAllAnimations()
            indicatorLayer.removeFromSuperlayer()
        } else if !oldStyle.isBusy && newStyle.isBusy {
            setNeedsLayout()
            layoutIfNeeded()
            let path = UIBezierPath(arcCenter: indicatorCenter,
                                    radius: indicatorLength / 2,
                                    startAngle: -(1 / 2) * .pi,
                                    endAngle: (3 / 2) * .pi,
                                    clockwise: true)
            indicatorLayer.path = path.cgPath
            indicatorLayer.strokeEnd = minStrokeEnd
            addBusyAnimation()
        }
        switch newStyle {
        case .finished(let showPlayIcon):
            backgroundView.isHidden = !showPlayIcon
            if showPlayIcon {
                setImage(iconSet.play, for: .normal)
            } else {
                setImage(nil, for: .normal)
            }
            isUserInteractionEnabled = false
        case .upload:
            backgroundView.isHidden = false
            setImage(iconSet.upload, for: .normal)
            isUserInteractionEnabled = true
        case .download:
            backgroundView.isHidden = false
            setImage(iconSet.download, for: .normal)
            isUserInteractionEnabled = true
        case .expired:
            backgroundView.isHidden = false
            setImage(iconSet.expired, for: .normal)
            isUserInteractionEnabled = false
        case .busy(let progress):
            backgroundView.isHidden = false
            if !oldStyle.isBusy {
                setImage(iconSet.cancel, for: .normal)
            }
            let progress = min(max(progress, minProgress), maxProgress)
            updateIndicatorLayer(progress: progress)
            isUserInteractionEnabled = true
        }
    }
    
    private func addBusyAnimation() {
        layer.addSublayer(indicatorLayer)
        let anim = CABasicAnimation(keyPath: "transform.rotation.z")
        anim.fromValue = indicatorLayer.value(forKeyPath: "transform.rotation.z")
        anim.toValue = 2 * CGFloat.pi
        anim.duration = 1
        anim.repeatCount = .greatestFiniteMagnitude
        anim.isRemovedOnCompletion = false
        indicatorLayer.add(anim, forKey: AnimationKey.rotation)
    }
    
    private func updateIndicatorLayer(progress: Double) {
        let newStrokeEnd = CGFloat(1 * progress)
        var oldStrokeEnd = indicatorLayer.presentation()?.strokeEnd ?? indicatorLayer.strokeEnd
        if oldStrokeEnd > newStrokeEnd {
            oldStrokeEnd = minStrokeEnd
        }
        
        let anim = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeEnd))
        anim.fromValue = oldStrokeEnd
        anim.toValue = newStrokeEnd
        anim.duration = 0.2
        anim.isRemovedOnCompletion = true
        
        indicatorLayer.removeAnimation(forKey: AnimationKey.strokeEnd)
        indicatorLayer.strokeEnd = newStrokeEnd
        indicatorLayer.add(anim, forKey: AnimationKey.strokeEnd)
    }
    
    private func prepare() {
        backgroundView.isUserInteractionEnabled = false
        insertSubview(backgroundView, at: 0)
        tintColor = indicatorColor
        imageView?.tintColor = indicatorColor
    }
    
}
