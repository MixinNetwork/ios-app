import UIKit

class ExternalSharingPreviewWrapperView: UIView {
    
    let outlineLayer = CAShapeLayer()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOutlineLayer()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOutlineLayer()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePath()
    }
    
    private func setupOutlineLayer() {
        outlineLayer.strokeColor = R.color.line()?.cgColor
        outlineLayer.fillColor = nil
        outlineLayer.lineDashPattern = [4, 4]
        outlineLayer.lineWidth = 2
        updatePath()
        layer.addSublayer(outlineLayer)
    }
    
    private func updatePath() {
        outlineLayer.path = CGPath(roundedRect: bounds,
                                   cornerWidth: layer.cornerRadius,
                                   cornerHeight: layer.cornerRadius,
                                   transform: nil)
    }
    
}
