import UIKit

class WaveformView: UIView {
    
    class var barWidth: CGFloat {
        return 2
    }
    
    class var layoutHeight: CGFloat {
        return 20
    }
    
    private class var barCornerRadius: CGFloat {
        return barWidth / 2
    }
    
    private class var yPositionSlope: CGFloat {
        return (layoutHeight - 2 * barCornerRadius) / CGFloat(maxLevel)
    }
    
    private class var yPositionIntercept: CGFloat {
        return 2 * barCornerRadius
    }
    
    private class var minLevel: UInt8 {
        return 0
    }
    
    private class var maxLevel: UInt8 {
        return .max
    }
    
    override var tintColor: UIColor! {
        didSet {
            guard tintColor != oldValue else {
                return
            }
            CATransaction.performWithoutAnimation {
                barLayers.forEach { (layer) in
                    layer.fillColor = tintColor.cgColor
                }
            }
        }
    }
    
    override var intrinsicContentSize: CGSize {
        guard let lastBarLayer = barLayers.last else {
            return .zero
        }
        return CGSize(width: lastBarLayer.frame.maxX,
                      height: type(of: self).layoutHeight)
    }
    
    var waveform: Waveform? {
        didSet {
            guard waveform != oldValue else {
                return
            }
            drawBars()
        }
    }
    
    private var barLayers = [CAShapeLayer]()
    
    private func makeBarLayer(forBarAtIndex index: Int, atLevel level: UInt8) -> CAShapeLayer {
        let size = CGSize(width: type(of: self).barWidth, height: type(of: self).layoutHeight)
        let layer = CAShapeLayer()
        let layerOrigin = CGPoint(x: (1.5 * CGFloat(index) + 0.5) * type(of: self).barWidth, y: 0)
        layer.frame = CGRect(origin: layerOrigin, size: size)
        let barHeight = CGFloat(level) * type(of: self).yPositionSlope + type(of: self).yPositionIntercept
        let pathRect = CGRect(x: 0,
                              y: type(of: self).layoutHeight - barHeight,
                              width: type(of: self).barWidth,
                              height: barHeight)
        let path = CGPath(roundedRect: pathRect,
                          cornerWidth: type(of: self).barCornerRadius,
                          cornerHeight: type(of: self).barCornerRadius,
                          transform: nil)
        layer.fillColor = tintColor.cgColor
        layer.path = path
        return layer
    }
    
    private func drawBars() {
        barLayers.forEach {
            $0.removeFromSuperlayer()
        }
        barLayers = []
        if let waveform = waveform {
            for (index, value) in waveform.values.enumerated() {
                let barLayer = makeBarLayer(forBarAtIndex: index, atLevel: value)
                layer.addSublayer(barLayer)
                barLayers.append(barLayer)
            }
        }
    }
    
    static func estimatedWidth(forDurationInSeconds duration: Int) -> CGFloat {
        let duration = max(Waveform.minDuration, min(Waveform.maxDuration, duration))
        let numberOfBars = Waveform.numberOfValues(forDurationInSeconds: duration)
        return 1.5 * barWidth * CGFloat(numberOfBars)
    }
    
}
