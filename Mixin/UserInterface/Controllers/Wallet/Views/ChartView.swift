import UIKit

final class ChartView: UIView {
    
    struct Point {
        let date: Date
        let value: Decimal
    }
    
    protocol Delegate: AnyObject {
        func chartView(_ view: ChartView, didSelectValue value: Decimal)
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
    
    private func redrawIfNeeded() {
        guard needsRedraw else {
            return
        }
        redraw()
    }
    
    private func redraw() {
        guard
            points.count >= 2,
            let maxValue = points.max(by: { $0.value < $1.value })?.value,
            let minValue = points.min(by: { $0.value < $1.value })?.value
        else {
            return
        }
        
        let firstValue = points[0].value
        let lastValue = points[points.count - 1].value
        let isRising = lastValue >= firstValue
        let color = isRising ? riseColor : fallColor
        
        let maxV = (maxValue as NSDecimalNumber).doubleValue
        let minV = (minValue as NSDecimalNumber).doubleValue
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
