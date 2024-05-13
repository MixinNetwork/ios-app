import UIKit
import MixinServices

final class InscriptionHashView: UIView {
    
    @IBInspectable var barWidth: CGFloat = 5
    @IBInspectable var barHeight: CGFloat = 16
    @IBInspectable var spacing: CGFloat = 3
    
    override var intrinsicContentSize: CGSize {
        contentSize
    }
    
    var content: String? {
        didSet {
            guard
                let hash = content,
                let hashData = Data(hexEncodedString: hash.prefix(64)),
                let suffix = SHA3_256.hash(data: hashData)?.prefix(4)
            else {
                layer.opacity = 0
                return
            }
            layer.opacity = 1
            let ingredients = hashData + suffix
            for (index, layer) in barLayers.enumerated() {
                let r = CGFloat(ingredients[index * 3]) / 255
                let g = CGFloat(ingredients[index * 3 + 1]) / 255
                let b = CGFloat(ingredients[index * 3 + 2]) / 255
                layer.backgroundColor = CGColor(red: r, green: g, blue: b, alpha: 1)
            }
        }
    }
    
    private let barLayers: [CALayer] = [
        CALayer(), CALayer(), CALayer(), CALayer(),
        CALayer(), CALayer(), CALayer(), CALayer(),
        CALayer(), CALayer(), CALayer(), CALayer(),
    ]
    
    private var contentSize: CGSize = .zero
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layoutBars()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layoutBars()
    }
    
    private func layoutBars() {
        for (index, barLayer) in barLayers.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing)
            barLayer.frame = CGRect(x: x, y: 0, width: barWidth, height: barHeight)
            layer.addSublayer(barLayer)
        }
        let contentWidth = CGFloat(barLayers.count) * barWidth + CGFloat(barLayers.count - 1) * spacing
        contentSize = CGSize(width: contentWidth, height: barHeight)
        invalidateIntrinsicContentSize()
    }
    
}
