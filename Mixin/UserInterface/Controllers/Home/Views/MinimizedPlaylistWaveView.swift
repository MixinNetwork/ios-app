import UIKit

class MinimizedPlaylistWaveView: UIView {
    
    private let waveBarLayer: CALayer = {
        let interbarSpace: CGFloat = 2
        let waveBarWidth: CGFloat = 2
        let waveBarHeights: [CGFloat] = [4, 10, 14, 10, 4]
        
        let background = CALayer()
        let backgroundWidth = CGFloat(waveBarHeights.count) * waveBarWidth
            + CGFloat(waveBarHeights.count - 1) * interbarSpace
        background.bounds.size = CGSize(width: backgroundWidth,
                                        height: waveBarHeights.max()!)
        background.backgroundColor = UIColor.clear.cgColor
        
        for (index, height) in waveBarHeights.enumerated() {
            let layer = CAShapeLayer()
            let shape = CGRect(x: 0, y: 0, width: waveBarWidth, height: height)
            layer.path = CGPath(roundedRect: shape,
                                cornerWidth: waveBarWidth / 2,
                                cornerHeight: waveBarWidth / 2,
                                transform: nil)
            layer.bounds.size = shape.size
            layer.position = CGPoint(x: CGFloat(index) * (waveBarWidth + interbarSpace),
                                     y: background.bounds.height / 2)
            background.addSublayer(layer)
        }
        return background
    }()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.addSublayer(waveBarLayer)
        updateWaveBarColor()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(waveBarLayer)
        updateWaveBarColor()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        waveBarLayer.position = CGPoint(x: layer.bounds.width / 2,
                                        y: layer.bounds.height / 2)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            updateWaveBarColor()
        }
    }
    
    private func updateWaveBarColor() {
        let color = R.color.icon_tint()!.cgColor
        waveBarLayer.sublayers?
            .compactMap({ $0 as? CAShapeLayer })
            .forEach({ $0.fillColor = color })
    }
    
}
