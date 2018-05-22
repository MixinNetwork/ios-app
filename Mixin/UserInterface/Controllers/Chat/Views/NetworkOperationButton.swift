import UIKit

class NetworkOperationButton: UIButton {
    
    static let indicatorLineWidth: CGFloat = 1.5
    static let buttonSize = #imageLiteral(resourceName: "ic_file_download").size
    static let indicatorLength: CGFloat = buttonSize.width - indicatorLineWidth
    
    private let minProgress: Double = 0.05
    private let maxProgress: Double = 0.95
    
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
    
    var style = Style.finished(showPlayIcon: false) {
        didSet {
            if oldValue.isBusy && !style.isBusy {
                removeBusyAnimation()
            } else if !oldValue.isBusy && style.isBusy {
                setNeedsLayout()
                layoutIfNeeded()
                addBusyAnimation()
            }
            switch style {
            case .finished(let showPlayIcon):
                setImage(showPlayIcon ? #imageLiteral(resourceName: "ic_play") : nil, for: .normal)
                isUserInteractionEnabled = false
            case .upload:
                setImage(#imageLiteral(resourceName: "ic_file_upload"), for: .normal)
                isUserInteractionEnabled = true
            case .download:
                setImage(#imageLiteral(resourceName: "ic_file_download"), for: .normal)
                isUserInteractionEnabled = true
            case .expired:
                setImage(#imageLiteral(resourceName: "ic_file_expired"), for: .normal)
                isUserInteractionEnabled = false
            case .busy(let progress):
                if !oldValue.isBusy {
                    setImage(#imageLiteral(resourceName: "ic_file_cancel"), for: .normal)
                }
                let progress = min(max(progress, minProgress), maxProgress)
                indicatorLayer.path = UIBezierPath(arcCenter: indicatorCenter,
                                                   radius: NetworkOperationButton.indicatorLength / 2,
                                                   startAngle: -.pi / 2,
                                                   endAngle: 2 * .pi * CGFloat(progress) - .pi / 2,
                                                   clockwise: true).cgPath
                isUserInteractionEnabled = true
            }
        }
    }
    
    private let busyAnimationKey = "BusyAnimation"
    
    private lazy var indicatorLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor(rgbValue: 0x007AFF).cgColor
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.lineWidth = NetworkOperationButton.indicatorLineWidth
        layer.lineCap = kCALineCapRound
        layer.path = UIBezierPath(arcCenter: .zero,
                                  radius: NetworkOperationButton.indicatorLength / 2,
                                  startAngle: -.pi / 2,
                                  endAngle: 3 / 4 * .pi,
                                  clockwise: true).cgPath
        return layer
    }()
    
    private var indicatorCenter = CGPoint.zero
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if style.isBusy {
            let indicatorLength = NetworkOperationButton.indicatorLength
            indicatorCenter = CGPoint(x: indicatorLength / 2, y: indicatorLength / 2)
            indicatorLayer.frame = CGRect(x: bounds.midX - indicatorLength / 2,
                                          y: bounds.midY - indicatorLength / 2,
                                          width: indicatorLength,
                                          height: indicatorLength)
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
    
}
