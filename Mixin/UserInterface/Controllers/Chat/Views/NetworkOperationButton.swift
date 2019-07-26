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
    
    let backgroundSize = CGSize(width: 38, height: 38)
    
    lazy var backgroundView: UIView = {
        let view = type(of: self).makeBackgroundView()
        view.tintColor = indicatorColor
        return view
    }()
    
    var style = Style.finished(showPlayIcon: false) {
        didSet {
            update(with: style, oldStyle: oldValue)
        }
    }
    
    var indicatorLineWidth: CGFloat {
        return 1.5
    }
    
    var indicatorColor: UIColor {
        return UIColor(displayP3RgbValue: 0x3D75E3)
    }
    
    private let minProgress: Double = 0.05
    private let maxProgress: Double = 0.95
    private let busyAnimationKey = "busy"
    
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
            removeBusyAnimation()
        } else if !oldStyle.isBusy && newStyle.isBusy {
            setNeedsLayout()
            layoutIfNeeded()
            addBusyAnimation()
        }
        switch newStyle {
        case .finished(let showPlayIcon):
            backgroundView.isHidden = !showPlayIcon
            if showPlayIcon {
                setImage(R.image.ic_play(), for: .normal)
            } else {
                setImage(nil, for: .normal)
            }
            isUserInteractionEnabled = false
        case .upload:
            backgroundView.isHidden = false
            setImage(R.image.ic_file_upload(), for: .normal)
            isUserInteractionEnabled = true
        case .download:
            backgroundView.isHidden = false
            setImage(R.image.ic_file_download(), for: .normal)
            isUserInteractionEnabled = true
        case .expired:
            backgroundView.isHidden = false
            setImage(R.image.ic_file_expired(), for: .normal)
            isUserInteractionEnabled = false
        case .busy(let progress):
            backgroundView.isHidden = false
            if !oldStyle.isBusy {
                setImage(R.image.ic_file_cancel(), for: .normal)
            }
            let progress = min(max(progress, minProgress), maxProgress)
            indicatorLayer.path = UIBezierPath(arcCenter: indicatorCenter,
                                               radius: indicatorLength / 2,
                                               startAngle: -.pi / 2,
                                               endAngle: 2 * .pi * CGFloat(progress) - .pi / 2,
                                               clockwise: true).cgPath
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
        indicatorLayer.add(anim, forKey: busyAnimationKey)
    }
    
    private func removeBusyAnimation() {
        indicatorLayer.removeAnimation(forKey: busyAnimationKey)
        indicatorLayer.removeFromSuperlayer()
    }
    
    private func prepare() {
        backgroundView.isUserInteractionEnabled = false
        insertSubview(backgroundView, at: 0)
        imageView?.tintColor = indicatorColor
    }
    
}
