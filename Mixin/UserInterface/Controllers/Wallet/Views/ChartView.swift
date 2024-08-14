import UIKit

final class ChartView: UIView {
    
    struct Point {
        let date: Date
        let value: Decimal
    }
    
    protocol Delegate: AnyObject {
        func chartView(_ view: ChartView, extremumAnnotationForPoint point: Point) -> String
        func chartView(_ view: ChartView, didSelectPoint point: Point)
    }
    
    weak var delegate: Delegate?
    
    var annotateExtremums = false {
        didSet {
            needsRedraw = true
            redrawIfNeeded()
        }
    }
    
    var points: [Point] = [] {
        didSet {
            needsRedraw = true
            redrawIfNeeded()
        }
    }
    
    private let lineLayer = CAShapeLayer()
    private let fillingLayer = CAGradientLayer()
    private let fillingLayerMask = CAShapeLayer()
    private let riseColor = R.color.green()!
    private let fallColor = R.color.red()!
    
    private var needsRedraw = false
    private var lastLayoutBounds: CGRect?
    private var extremumAnnotationLayers: [CALayer] = []
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadSublayers()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSublayers()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds != lastLayoutBounds {
            lineLayer.frame = bounds
            fillingLayer.frame = bounds
            fillingLayerMask.frame = bounds
            redrawIfNeeded()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            redraw()
        }
    }
    
    private func redrawIfNeeded() {
        guard needsRedraw else {
            return
        }
        redraw()
    }
    
    private func redraw() {
        for layer in extremumAnnotationLayers {
            layer.removeFromSuperlayer()
        }
        extremumAnnotationLayers = []
        
        guard points.count >= 2 else {
            lineLayer.opacity = 0
            fillingLayer.opacity = 0
            return
        }
        
        var maxIndex = 0
        var minIndex = 0
        for (i, point) in points.enumerated() {
            if point.value > points[maxIndex].value {
                maxIndex = i
            } else if point.value < points[minIndex].value {
                minIndex = i
            }
        }
        
        let firstValue = points[0].value
        let lastValue = points[points.count - 1].value
        let isRising = lastValue >= firstValue
        let color = isRising ? riseColor : fallColor
        
        let maxV = (points[maxIndex].value as NSDecimalNumber).doubleValue
        let minV = (points[minIndex].value as NSDecimalNumber).doubleValue
        let minY = (44 - 6) / 44 * bounds.height
        let maxY = 4 / 44 * bounds.height
        let a = (maxY - minY) / (maxV - minV)
        let b = maxY - a * maxV
        let xUnit = bounds.width / CGFloat(points.count)
        let drawingPoints = points.enumerated().map { (i, point) in
            let v = (point.value as NSDecimalNumber).doubleValue
            let y = a * v + b
            let x = CGFloat(i) * xUnit // TODO: Calculate with `Point.date`
            return CGPoint(x: x, y: y)
        }
        let linePath = CGMutablePath()
        linePath.move(to: drawingPoints[0])
        for point in drawingPoints.suffix(drawingPoints.count - 1) {
            linePath.addLine(to: point)
        }
        lineLayer.path = linePath
        lineLayer.strokeColor = color.cgColor
        lineLayer.opacity = 1
        
        if let fillingMaskPath = linePath.mutableCopy() {
            let bottomRight = CGPoint(x: bounds.width, y: bounds.height)
            fillingMaskPath.addLine(to: bottomRight)
            let bottomLeft = CGPoint(x: 0, y: bounds.height)
            fillingMaskPath.addLine(to: bottomLeft)
            fillingMaskPath.addLine(to: drawingPoints[0])
            fillingLayerMask.path = fillingMaskPath
        } else {
            fillingLayerMask.path = nil
        }
        fillingLayer.colors = [color.cgColor, color.withAlphaComponent(0).cgColor]
        fillingLayer.opacity = 1
        
        if annotateExtremums {
            let maxDotLayer = AnnotationDotLayer(color: color)
            maxDotLayer.position = drawingPoints[maxIndex]
            layer.addSublayer(maxDotLayer)
            
            let minDotLayer = AnnotationDotLayer(color: color)
            minDotLayer.position = drawingPoints[minIndex]
            layer.addSublayer(minDotLayer)
            
            extremumAnnotationLayers = [maxDotLayer, minDotLayer]
            
            if let text = delegate?.chartView(self, extremumAnnotationForPoint: points[maxIndex]) {
                let maxTextLayer = AnnotationTextLayer(text: text, color: color)
                layer.addSublayer(maxTextLayer)
                let size = maxTextLayer.preferredFrameSize()
                maxTextLayer.frame.size = size
                maxTextLayer.frame.origin = CGPoint(
                    x: min(bounds.width - size.width, max(0, maxDotLayer.position.x - size.width / 2)),
                    y: maxDotLayer.frame.minY - size.height
                )
                extremumAnnotationLayers.append(maxTextLayer)
            }
            
            if let text = delegate?.chartView(self, extremumAnnotationForPoint: points[minIndex]) {
                let minTextLayer = AnnotationTextLayer(text: text, color: color)
                layer.addSublayer(minTextLayer)
                let size = minTextLayer.preferredFrameSize()
                minTextLayer.frame.size = size
                minTextLayer.frame.origin = CGPoint(
                    x: min(bounds.width - size.width, max(0, minDotLayer.position.x - size.width / 2)),
                    y: minDotLayer.frame.maxY
                )
                extremumAnnotationLayers.append(minTextLayer)
            }
        }
    }
    
    private func loadSublayers() {
        fillingLayer.mask = fillingLayerMask
        layer.addSublayer(fillingLayer)
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.opacity = 1
        lineLayer.lineWidth = 2
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        layer.addSublayer(lineLayer)
    }
    
}

extension ChartView {
    
    // Do not draw it with a bordered layer. The edge is visible and ugly.
    private class AnnotationDotLayer: CALayer {
        
        init(color: UIColor) {
            super.init()
            
            backgroundColor = R.color.background()!.cgColor
            frame.size = CGSize(width: 10, height: 10)
            cornerRadius = 5
            masksToBounds = true
            
            let dotLayer = CALayer()
            dotLayer.backgroundColor = color.cgColor
            dotLayer.frame.size = CGSize(width: 6, height: 6)
            dotLayer.cornerRadius = 3
            dotLayer.masksToBounds = true
            addSublayer(dotLayer)
            dotLayer.position = CGPoint(x: 5, y: 5)
        }
        
        override init(layer: Any) {
            super.init(layer: layer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("Not supported")
        }
        
    }
    
    private class AnnotationTextLayer: CATextLayer {
        
        init(text: String, color: UIColor) {
            super.init()
            fontSize = 14
            string = text
            foregroundColor = color.cgColor
            contentsScale = UIScreen.main.scale
        }
        
        override init(layer: Any) {
            super.init(layer: layer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("Not supported")
        }
        
    }
    
}
