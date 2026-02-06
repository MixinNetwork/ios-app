import UIKit

final class BarChartView: UIView {
    
    var proportions = [Double]() {
        didSet {
            CATransaction.performWithoutAnimation(draw)
        }
    }
    
    private let barLayersContainerLayer = CALayer()
    private var barLayers = [CAGradientLayer]()
    private var shadowLayers = [CAShapeLayer]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        barLayersContainerLayer.masksToBounds = true
        layer.addSublayer(barLayersContainerLayer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        barLayersContainerLayer.masksToBounds = true
        layer.addSublayer(barLayersContainerLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.performWithoutAnimation(layoutLayers)
    }
    
    private func draw() {
        assert(proportions.count <= 3)
        let barsCount = max(1, proportions.count)
        let numberOfLayersToBeAdded = barsCount - barLayers.count
        if numberOfLayersToBeAdded > 0 {
            for _ in 0..<numberOfLayersToBeAdded {
                let layer = CAGradientLayer()
                layer.startPoint = CGPoint(x: 0, y: 0)
                layer.endPoint = CGPoint(x: 1, y: 1)
                layer.locations = [0, 1]
                barLayersContainerLayer.addSublayer(layer)
                barLayers.append(layer)
                
                let shadowLayer = CAShapeLayer()
                shadowLayer.fillColor = UIColor.clear.cgColor
                shadowLayer.shadowOpacity = 0.21
                shadowLayer.shadowRadius = 4
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
        
        if proportions.isEmpty {
            barLayers.first?.colors = [
                UIColor(displayP3RgbValue: 0xE5E8EE).cgColor,
                UIColor(displayP3RgbValue: 0xE5E8EE).cgColor,
            ]
            shadowLayers.first?.shadowColor = UIColor(displayP3RgbValue: 0x888888, alpha: 0.1).cgColor
        } else {
            for i in 0..<barLayers.count {
                barLayers[i].colors = barColors(at: i, count: barsCount)
            }
            for i in 0..<shadowLayers.count {
                shadowLayers[i].shadowColor = shadowColor(at: i, count: barsCount)
            }
        }
        
        layoutLayers()
    }
    
    private func layoutLayers() {
        barLayersContainerLayer.frame = bounds
        barLayersContainerLayer.cornerRadius = bounds.height / 2
        if proportions.isEmpty {
            barLayers.first?.frame = CGRect(origin: .zero, size: bounds.size)
        } else {
            for i in 0..<proportions.count {
                let size = CGSize(width: CGFloat(proportions[i]) * bounds.width, height: bounds.height)
                if i == 0 {
                    barLayers[i].frame = CGRect(origin: .zero, size: size)
                } else {
                    barLayers[i].frame = CGRect(x: barLayers[i - 1].frame.maxX, y: 0, width: size.width, height: size.height)
                }
            }
        }
        for i in 0..<barLayers.count {
            shadowLayers[i].frame = barLayersContainerLayer.convert(barLayers[i].frame, to: layer)
            let cornerRadius = shadowLayers[i].bounds.height / 2
            let pathRect = shadowLayers[i].bounds
            let shadowPathRect = CGRect(
                x: 0,
                y: 5,
                width: shadowLayers[i].bounds.width,
                height: shadowLayers[i].bounds.height
            )
            if cornerRadius <= pathRect.width / 2 {
                shadowLayers[i].path = CGPath(
                    roundedRect: pathRect,
                    cornerWidth: cornerRadius,
                    cornerHeight: cornerRadius,
                    transform: nil
                )
                shadowLayers[i].shadowPath = CGPath(
                    roundedRect: shadowPathRect,
                    cornerWidth: cornerRadius,
                    cornerHeight: cornerRadius,
                    transform: nil
                )
            } else {
                shadowLayers[i].path = CGPath(rect: pathRect, transform: nil)
                shadowLayers[i].shadowPath = CGPath(rect: shadowPathRect, transform: nil)
            }
        }
    }
    
    private func barColors(at index: Int, count: Int) -> [CGColor] {
        let values: [UInt] = switch index {
        case 0:
            [0x47A1FF, 0x244BFF]
        case 1:
            if count == 3 {
                [0xB852F6, 0xED1C80]
            } else {
                [0xFFBB54, 0xFF9E2C]
            }
        default:
            [0xFFBB54, 0xFF9E2C]
        }
        return values.map { value in
            UIColor(rgbValue: value).cgColor
        }
    }
    
    private func shadowColor(at index: Int, count: Int) -> CGColor {
        switch index {
        case 0:
            UIColor(rgbValue: 0x246BFF).cgColor
        case 1:
            if count == 3 {
                UIColor(rgbValue: 0x491DF6).cgColor
            } else {
                UIColor(rgbValue: 0xF3962C).cgColor
            }
        default:
            UIColor(rgbValue: 0xF3962C).cgColor
        }
    }
    
}
