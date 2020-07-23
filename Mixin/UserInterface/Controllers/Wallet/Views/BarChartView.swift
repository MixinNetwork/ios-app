import UIKit

class BarChartView: UIView {
    
    var proportions = [Double]() {
        didSet {
            CATransaction.performWithoutAnimation {
                draw(oldProportions: oldValue)
            }
        }
    }
    
    private let barLayersContainerLayer = CALayer()
    private var barLayers = [CAGradientLayer]()
    private var shadowLayers = [CAShapeLayer]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.performWithoutAnimation {
            layoutLayers()
        }
    }
    
    private func prepare() {
        barLayersContainerLayer.masksToBounds = true
        layer.addSublayer(barLayersContainerLayer)
    }
    
    private func draw(oldProportions: [Double]) {
        assert(proportions.count <= 3)
        guard proportions != oldProportions else {
            return
        }
        let numberOfLayersToBeAdded = proportions.count - oldProportions.count
        if numberOfLayersToBeAdded > 0 {
            for i in 0..<numberOfLayersToBeAdded {
                let index = oldProportions.count + i
                let layer = makeBarLayer(at: index, count: proportions.count)
                barLayersContainerLayer.addSublayer(layer)
                barLayers.append(layer)
                let shadowLayer = makeShadowLayer(at: index, count: proportions.count)
                shadowLayer.fillColor = UIColor.clear.cgColor
                self.layer.insertSublayer(shadowLayer, at: 0)
                shadowLayers.append(shadowLayer)
            }
        } else if numberOfLayersToBeAdded < 0 {
            barLayers
                .suffix(-numberOfLayersToBeAdded)
                .forEach({ $0.removeFromSuperlayer() })
            barLayers
                .removeLast(-numberOfLayersToBeAdded)
            shadowLayers
                .suffix(-numberOfLayersToBeAdded)
                .forEach({ $0.removeFromSuperlayer() })
            shadowLayers
                .removeLast(-numberOfLayersToBeAdded)
        }
        layoutLayers()
    }
    
    private func layoutLayers() {
        assert(proportions.count == barLayers.count)
        assert(proportions.count == shadowLayers.count)
        barLayersContainerLayer.frame = bounds
        barLayersContainerLayer.cornerRadius = bounds.height / 2
        for i in 0..<proportions.count {
            let size = CGSize(width: CGFloat(proportions[i]) * bounds.width, height: bounds.height)
            if i == 0 {
                barLayers[i].frame = CGRect(origin: .zero, size: size)
            } else {
                barLayers[i].frame = CGRect(x: barLayers[i - 1].frame.maxX, y: 0, width: size.width, height: size.height)
            }
            shadowLayers[i].frame = barLayersContainerLayer.convert(barLayers[i].frame, to: layer)
            let cornerRadius = shadowLayers[i].bounds.height / 2
            let pathRect = shadowLayers[i].bounds
            let shadowPathRect = CGRect(x: 0, y: 5, width: shadowLayers[i].bounds.width, height: shadowLayers[i].bounds.height)
            if cornerRadius <= pathRect.width / 2 {
                shadowLayers[i].path = CGPath(roundedRect: pathRect,
                                              cornerWidth: cornerRadius,
                                              cornerHeight: cornerRadius,
                                              transform: nil)
                shadowLayers[i].shadowPath = CGPath(roundedRect: shadowPathRect,
                                                    cornerWidth: cornerRadius,
                                                    cornerHeight: cornerRadius,
                                                    transform: nil)
            } else {
                shadowLayers[i].path = CGPath(rect: pathRect, transform: nil)
                shadowLayers[i].shadowPath = CGPath(rect: shadowPathRect, transform: nil)
            }
        }
    }
    
    private func makeBarLayer(at index: Int, count: Int) -> CAGradientLayer {
        let layer = CAGradientLayer()
        switch index {
        case 0:
            layer.colors = [UIColor(rgbValue: 0x47A1FF).cgColor,
                            UIColor(rgbValue: 0x244BFF).cgColor]
        case 1:
            if count == 3 {
                layer.colors = [UIColor(rgbValue: 0xB852F6).cgColor,
                                UIColor(rgbValue: 0xED1C80).cgColor]
            } else {
                layer.colors = [UIColor(rgbValue: 0xFFBB54).cgColor,
                                UIColor(rgbValue: 0xFF9E2C).cgColor]
            }
        default:
            layer.colors = [UIColor(rgbValue: 0xFFBB54).cgColor,
                            UIColor(rgbValue: 0xFF9E2C).cgColor]
        }
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        layer.locations = [0, 1]
        return layer
    }
    
    private func makeShadowLayer(at index: Int, count: Int) -> CAShapeLayer {
        let layer = CAShapeLayer()
        
        switch index {
        case 0:
            layer.shadowColor = UIColor(rgbValue: 0x246BFF).cgColor
        case 1:
            if count == 3 {
                layer.shadowColor = UIColor(rgbValue: 0x491DF6).cgColor
            } else {
                layer.shadowColor = UIColor(rgbValue: 0xF3962C).cgColor
            }
        default:
            layer.shadowColor = UIColor(rgbValue: 0xF3962C).cgColor
        }
        layer.shadowOpacity = 0.21
        layer.shadowRadius = 4
        return layer
    }
    
}
