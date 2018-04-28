import UIKit

class PieChartView: UIView {

    var segments = [PieSegment]() {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return
        }

        let radius = min(frame.size.width, frame.size.height) * 0.5
        let viewCenter = CGPoint(x: bounds.size.width * 0.5, y: bounds.size.height * 0.5)
        let valueCount = segments.reduce(0, {$0 + CGFloat($1.value)})
        var startAngle = -CGFloat.pi * 0.5
        for segment in segments {
            ctx.setFillColor(segment.color.cgColor)
            let endAngle = startAngle + 2 * .pi * (CGFloat(segment.value) / valueCount)
            ctx.move(to: viewCenter)
            ctx.addArc(center: viewCenter, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            ctx.fillPath()
            startAngle = endAngle
        }
    }
}


struct PieSegment {

    var color: UIColor
    var value: Double
    var symbol: String
}
