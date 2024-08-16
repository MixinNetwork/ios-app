import UIKit

final class ChartView: UIView {
    
    struct Point {
        let date: Date
        let value: Decimal
    }
    
    protocol Delegate: AnyObject {
        func chartView(_ view: ChartView, extremumAnnotationForPoint point: Point) -> String
        func chartView(_ view: ChartView, inspectionAnnotationForPoint point: Point) -> String
        func chartView(_ view: ChartView, didSelectPoint point: Point)
        func chartViewDidCancelSelection(_ view: ChartView)
    }
    
    weak var delegate: Delegate?
    
    override var isUserInteractionEnabled: Bool {
        didSet {
            setupRecognizerIfNeeded()
        }
    }
    
    var annotateExtremums = false {
        didSet {
            redraw()
        }
    }
    
    var points: [Point] = [] {
        didSet {
            if let firstValue = points.first?.value, let lastValue = points.last?.value {
                arePointsRising = lastValue >= firstValue
            } else {
                arePointsRising = true
            }
            redraw()
        }
    }
    
    var minPointPosition: CGFloat = (44 - 6) / 44 {
        didSet {
            redraw()
        }
    }
    
    var maxPointPosition: CGFloat = 4 / 44 {
        didSet {
            redraw()
        }
    }
    
    private let lineLayer = CAShapeLayer()
    private let fillingLayer = CAGradientLayer()
    private let fillingLayerMask = CAShapeLayer()
    
    private var lastLayoutBounds: CGRect?
    private var drawingPoints: [CGPoint] = []
    private var arePointsRising: Bool = true
    private var extremumAnnotationLayers: [CALayer] = []
    private var extremumAnnotationViews: [UIView] = []
    
    private weak var inspectionRecognizer: UIGestureRecognizer?
    private weak var cursorView: VerticalDashLineView?
    private weak var cursorViewCenterXConstraint: NSLayoutConstraint?
    private weak var cursorDotLayer: CALayer?
    private weak var inspectionAnnotationLabel: UILabel?
    private weak var inspectionAnnotationLabelCenterXConstraint: NSLayoutConstraint?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadSublayers()
        setupRecognizerIfNeeded()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSublayers()
        setupRecognizerIfNeeded()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds != lastLayoutBounds {
            lineLayer.frame = bounds
            fillingLayer.frame = bounds
            fillingLayerMask.frame = bounds
            redraw()
            self.lastLayoutBounds = bounds
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            redraw()
        }
    }
    
    @objc private func inspect(_ recognizer: InspectionGestureRecognizer) {
        let x = {
            var x = recognizer.location(in: self).x
            x = max(0, min(bounds.width, x))
            return x
        }()
        let point: Point = {
            var index = Int(round(x / bounds.width * Double(points.count)))
            index = max(0, min(points.count - 1, index))
            return points[index]
        }()
        switch recognizer.state {
        case .began:
            if cursorDotLayer == nil {
                let backgroundColor = R.color.background()!.resolvedColor(with: traitCollection)
                let dotColor: UIColor = arePointsRising ? .priceRising : .priceFalling
                let dot = AnnotationDotLayer(backgroundColor: backgroundColor.cgColor, dotColor: dotColor.cgColor)
                layer.addSublayer(dot)
                if let y = drawingPoint(around: x)?.y {
                    dot.position = CGPoint(x: x, y: y)
                }
                dot.zPosition = .greatestFiniteMagnitude
                cursorDotLayer = dot
            }
            if cursorView == nil {
                let view = VerticalDashLineView()
                addSubview(view)
                view.snp.makeConstraints { make in
                    make.top.bottom.equalToSuperview()
                    make.width.equalTo(1)
                }
                let constraint = view.centerXAnchor.constraint(equalTo: leadingAnchor, constant: x)
                constraint.isActive = true
                cursorView = view
                cursorViewCenterXConstraint = constraint
            }
            if inspectionAnnotationLabel == nil {
                let label = UILabel()
                label.font = .systemFont(ofSize: 12)
                label.textColor = R.color.text_quaternary()
                label.text = delegate?.chartView(self, inspectionAnnotationForPoint: point)
                addSubview(label)
                label.snp.makeConstraints { make in
                    make.bottom.equalTo(snp.top).offset(-6)
                    make.leading.greaterThanOrEqualToSuperview()
                    make.trailing.lessThanOrEqualToSuperview()
                }
                let constraint = label.centerXAnchor.constraint(equalTo: leadingAnchor, constant: x)
                constraint.priority = .defaultHigh
                constraint.isActive = true
                inspectionAnnotationLabel = label
                inspectionAnnotationLabelCenterXConstraint = constraint
            }
            delegate?.chartView(self, didSelectPoint: point)
        case .changed:
            if let dot = cursorDotLayer, let y = drawingPoint(around: x)?.y {
                CATransaction.performWithoutAnimation {
                    dot.position = CGPoint(x: x, y: y)
                }
            }
            if let constraint = cursorViewCenterXConstraint {
                constraint.constant = x
            }
            if let label = inspectionAnnotationLabel {
                label.text = delegate?.chartView(self, inspectionAnnotationForPoint: point)
            }
            if let constraint = inspectionAnnotationLabelCenterXConstraint {
                constraint.constant = x
            }
            layoutIfNeeded()
            delegate?.chartView(self, didSelectPoint: point)
        case .ended, .cancelled, .failed:
            cursorDotLayer?.removeFromSuperlayer()
            cursorView?.removeFromSuperview()
            inspectionAnnotationLabel?.removeFromSuperview()
            delegate?.chartViewDidCancelSelection(self)
        case .possible, .recognized:
            break
        @unknown default:
            break
        }
    }
    
    private func drawingPoint(around x: CGFloat) -> CGPoint? {
        guard !drawingPoints.isEmpty else {
            return nil
        }
        var index = Int(round(x / bounds.width * Double(drawingPoints.count)))
        index = max(0, min(points.count - 1, index))
        return drawingPoints[index]
    }
    
    private func redraw() {
        for layer in extremumAnnotationLayers {
            layer.removeFromSuperlayer()
        }
        extremumAnnotationLayers = []
        for view in extremumAnnotationViews {
            view.removeFromSuperview()
        }
        extremumAnnotationViews = []
        drawingPoints = []
        
        guard points.count >= 2 else {
            CATransaction.performWithoutAnimation {
                lineLayer.opacity = 0
                fillingLayer.opacity = 0
            }
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
        
        let color = (arePointsRising ? UIColor.priceRising : UIColor.priceFalling)
            .resolvedColor(with: traitCollection)
        
        let maxV = (points[maxIndex].value as NSDecimalNumber).doubleValue
        let minV = (points[minIndex].value as NSDecimalNumber).doubleValue
        let minY = minPointPosition * bounds.height
        let maxY = maxPointPosition * bounds.height
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
        CATransaction.performWithoutAnimation {
            lineLayer.opacity = 1
        }
        self.drawingPoints = drawingPoints
        
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
        CATransaction.performWithoutAnimation {
            fillingLayer.opacity = 1
        }
        
        if annotateExtremums {
            let backgroundColor = R.color.background()!.resolvedColor(with: traitCollection)
            let dotColor: UIColor = arePointsRising ? .priceRising : .priceFalling
            
            let maxDotLayer = AnnotationDotLayer(
                backgroundColor: backgroundColor.cgColor,
                dotColor: dotColor.cgColor
            )
            maxDotLayer.position = drawingPoints[maxIndex]
            layer.addSublayer(maxDotLayer)
            
            let minDotLayer = AnnotationDotLayer(
                backgroundColor: backgroundColor.cgColor,
                dotColor: dotColor.cgColor
            )
            minDotLayer.position = drawingPoints[minIndex]
            layer.addSublayer(minDotLayer)
            
            extremumAnnotationLayers = [maxDotLayer, minDotLayer]
            
            if let text = delegate?.chartView(self, extremumAnnotationForPoint: points[maxIndex]) {
                let maxLabel = AnnotationLabel(text: text, color: color)
                addSubview(maxLabel)
                maxLabel.snp.makeConstraints { make in
                    make.bottom.equalTo(snp.top)
                        .offset(maxDotLayer.frame.minY)
                    make.centerX.equalTo(snp.leading)
                        .offset(maxDotLayer.position.x)
                        .priority(.high)
                    make.leading.greaterThanOrEqualToSuperview()
                    make.trailing.lessThanOrEqualToSuperview()
                }
                extremumAnnotationViews.append(maxLabel)
            }
            
            if let text = delegate?.chartView(self, extremumAnnotationForPoint: points[minIndex]) {
                let minLabel = AnnotationLabel(text: text, color: color)
                addSubview(minLabel)
                minLabel.snp.makeConstraints { make in
                    make.top.equalToSuperview()
                        .offset(minDotLayer.frame.maxY)
                    make.centerX.equalTo(snp.leading)
                        .offset(minDotLayer.position.x)
                        .priority(.high)
                    make.leading.greaterThanOrEqualToSuperview()
                    make.trailing.lessThanOrEqualToSuperview()
                }
                extremumAnnotationViews.append(minLabel)
            }
        }
    }
    
    private func setupRecognizerIfNeeded() {
        if isUserInteractionEnabled && inspectionRecognizer == nil {
            let recognizer = InspectionGestureRecognizer(target: self, action: #selector(inspect(_:)))
            addGestureRecognizer(recognizer)
            self.inspectionRecognizer = recognizer
        }
    }
    
    private func loadSublayers() {
        fillingLayer.mask = fillingLayerMask
        layer.addSublayer(fillingLayer)
        
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.opacity = 1
        lineLayer.lineWidth = 1
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        layer.addSublayer(lineLayer)
    }
    
}

extension ChartView {
    
    // Do not draw it with a bordered layer. The edge is visible and ugly.
    private class AnnotationDotLayer: CALayer {
        
        init(backgroundColor: CGColor, dotColor: CGColor) {
            super.init()
            
            self.backgroundColor = backgroundColor
            self.frame.size = CGSize(width: 10, height: 10)
            self.cornerRadius = 5
            self.masksToBounds = true
            
            let dotLayer = CALayer()
            dotLayer.backgroundColor = dotColor
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
    
    private class AnnotationLabel: UILabel {
        
        init(text: String, color: UIColor) {
            super.init(frame: .zero)
            self.font = .systemFont(ofSize: 14, weight: .medium)
            self.textColor = color
            self.text = text
        }
        
        required init?(coder: NSCoder) {
            fatalError("Not supported")
        }
        
    }
    
    private class InspectionGestureRecognizer: UIGestureRecognizer {
        
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)
            state = .began
        }
        
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesMoved(touches, with: event)
            state = .changed
        }
        
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesCancelled(touches, with: event)
            state = .cancelled
        }
        
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesEnded(touches, with: event)
            state = .ended
        }
        
    }
    
    private class VerticalDashLineView: UIView {
        
        private let lineWidth: CGFloat = 1
        private let lineColor: UIColor = R.color.chat_pin_count_background()!
        private let numberOfDashes: CGFloat = 22
        private let lineLayer = CAShapeLayer()
        
        private var lastLayoutBounds: CGRect?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadLayer()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadLayer()
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            if lastLayoutBounds != bounds {
                lineLayer.frame.size = CGSize(width: lineWidth, height: bounds.height)
                lineLayer.position = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
                
                let path = CGMutablePath()
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: 0, y: bounds.height))
                lineLayer.path = path
                
                let dashLength = bounds.height / (numberOfDashes * 2 + 1)
                lineLayer.lineDashPattern = [NSNumber(value: dashLength), NSNumber(value: dashLength)]
                
                lastLayoutBounds = bounds
            }
        }
        
        private func loadLayer() {
            lineLayer.fillColor = UIColor.clear.cgColor
            lineLayer.strokeColor = lineColor.cgColor
            lineLayer.lineWidth = lineWidth
            lineLayer.lineJoin = .round
            layer.addSublayer(lineLayer)
        }
        
    }
    
}
