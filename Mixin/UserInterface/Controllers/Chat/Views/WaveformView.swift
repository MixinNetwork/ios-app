import UIKit

class WaveformView: UIView {
    
    var waveform: Waveform? {
        didSet {
            guard waveform != oldValue else {
                return
            }
            drawBars()
        }
    }
    
    private static let barWidth: CGFloat = 2
    private static let barCornerRadius = barWidth / 2
    private static let layoutHeight: CGFloat = 20
    private static let yPositionSlope = (layoutHeight - 2 * barCornerRadius) / CGFloat(maxLevel)
    private static let yPositionIntercept = 2 * barCornerRadius
    
    private static let minLevel = 0
    private static let maxLevel = UInt8.max
    
    private var barLayers = [CAShapeLayer]()
    
    private func makeBarLayer(forBarAtIndex index: Int, atLevel level: UInt8) -> CAShapeLayer {
        let size = CGSize(width: WaveformView.barWidth, height: WaveformView.layoutHeight)
        let layer = CAShapeLayer()
        let layerOrigin = CGPoint(x: (1.5 * CGFloat(index) + 0.5) * WaveformView.barWidth, y: 0)
        layer.frame = CGRect(origin: layerOrigin, size: size)
        let barHeight = CGFloat(level) * WaveformView.yPositionSlope + WaveformView.yPositionIntercept
        let pathRect = CGRect(x: 0,
                              y: WaveformView.layoutHeight - barHeight,
                              width: WaveformView.barWidth,
                              height: barHeight)
        let path = CGPath(roundedRect: pathRect,
                          cornerWidth: WaveformView.barCornerRadius,
                          cornerHeight: WaveformView.barCornerRadius,
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
