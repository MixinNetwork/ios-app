import UIKit

final class CandlestickChartView: UIView {
    
    struct Candle {
        let time: Date
        let open: CGFloat
        let high: CGFloat
        let low: CGFloat
        let close: CGFloat
    }
    
    private enum Layout {
        static let candleAreaHeightFraction: CGFloat = 2.0 / 3.0
        static let candleBodyWidthFraction: CGFloat = 0.6
        static let wickWidthPt: CGFloat = 1.5
        static let priceAxisWidth: CGFloat = 52
        static let gridLineCount: Int = 6
    }
    
    private enum Style {
        static let bullishColor   = UIColor(red: 0.18, green: 0.78, blue: 0.56, alpha: 1)   // green
        static let bearishColor   = UIColor(red: 0.95, green: 0.32, blue: 0.32, alpha: 1)   // red
        static let gridLineColor  = UIColor(displayP3RgbValue: 0xb3b3b3, alpha: 1)
        static let priceTextColor = R.color.text_tertiary()!
        static let highLineColor  = R.color.text_tertiary()!
        static let highLabelBg    = R.color.background()!
        static let priceFontSize: CGFloat = 9.5
        static let highLabelFontSize: CGFloat = 9.5
    }
    
    var candles: [Candle] = [] {
        didSet { reloadChart() }
    }
    
    private let chartContainer = CALayer()
    private var candleLayers: [CALayer] = []
    private var gridLayers: [CALayer] = []
    private var priceLabelLayers: [CATextLayer] = []
    
    private let highLineLayer   = CAShapeLayer()
    private let highLabelLayer  = CALayer()
    private let highLabelText   = CATextLayer()
    private let highLabelBadge  = CALayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        layer.addSublayer(chartContainer)
        setupHighLineLayers()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        chartContainer.frame = bounds
        reloadChart()
    }
    
    func reloadChart() {
        guard !bounds.isEmpty, !candles.isEmpty else {
            return
        }
        clearSublayers()
        drawGrid()
        drawCandles()
        animateHighLine()
    }
    
    private func setupHighLineLayers() {
        // Dotted line
        highLineLayer.fillColor   = nil
        highLineLayer.strokeColor = Style.highLineColor.cgColor
        highLineLayer.lineWidth   = 1.2
        highLineLayer.lineDashPattern = [4, 4]
        highLineLayer.opacity     = 0
        layer.addSublayer(highLineLayer)
        
        // Badge background
        highLabelBadge.backgroundColor = Style.highLabelBg.cgColor
        highLabelBadge.cornerRadius    = 3
        
        // Badge text
        highLabelText.font            = UIFont.monospacedSystemFont(ofSize: Style.highLabelFontSize, weight: .semibold) as CTFont
        highLabelText.fontSize        = Style.highLabelFontSize
        highLabelText.foregroundColor = R.color.text()!.cgColor
        highLabelText.contentsScale   = UIScreen.main.scale
        highLabelText.alignmentMode   = .center
        highLabelText.borderColor = R.color.text()!.cgColor
        highLabelText.borderWidth = 1
        highLabelText.cornerRadius = 2
        highLabelText.masksToBounds = true
        
        highLabelLayer.opacity = 0
        highLabelLayer.addSublayer(highLabelBadge)
        highLabelLayer.addSublayer(highLabelText)
        layer.addSublayer(highLabelLayer)
    }
    
    private func clearSublayers() {
        // Remove old candle / grid / label layers from container
        chartContainer.sublayers?.forEach { $0.removeFromSuperlayer() }
        candleLayers.removeAll()
        gridLayers.removeAll()
        priceLabelLayers.removeAll()
        
        // Reset high line (will be re-added in animateHighLine)
        highLineLayer.path    = nil
        highLineLayer.opacity = 0
        highLabelLayer.opacity = 0
    }
    
    private var priceRange: (min: CGFloat, max: CGFloat) {
        let allPrices = candles.flatMap { [$0.high, $0.low] }
        return (allPrices.min() ?? 0, allPrices.max() ?? 1)
    }
    
    private func yForPrice(_ price: CGFloat, in rect: CGRect, minP: CGFloat, maxP: CGFloat) -> CGFloat {
        let range = maxP - minP
        guard range > 0 else { return rect.midY }
        let fraction = (price - minP) / range   // 0 = bottom, 1 = top
        return rect.maxY - fraction * rect.height
    }
    
    private func drawGrid() {
        let totalW = bounds.width
        let totalH = bounds.height
        let axisW  = Layout.priceAxisWidth
        let drawW  = totalW - axisW   // drawable width (left of the axis)
        
        let (minP, maxP) = priceRange
        let priceStep = (maxP - minP) / CGFloat(Layout.gridLineCount - 1)
        
        // Grid lines span the FULL height; price labels are positioned to match
        // the candle area (center 2/3), so the top/bottom grid labels sit outside
        // the candle extremes — giving the chart visual breathing room.
        let candleH    = totalH * Layout.candleAreaHeightFraction
        let candleTopY = (totalH - candleH) / 2
        let candleRect = CGRect(x: 0, y: candleTopY, width: drawW, height: candleH)
        
        let font = UIFont.monospacedSystemFont(ofSize: Style.priceFontSize, weight: .regular)
        
        for i in 0..<Layout.gridLineCount {
            let price = minP + CGFloat(i) * priceStep
            // Y is computed against the candle rect so labels align with candle prices
            let y = yForPrice(price, in: candleRect, minP: minP, maxP: maxP)
            
            // Horizontal line — full drawable width, at the price-mapped Y
            let line = CALayer()
            line.backgroundColor = Style.gridLineColor.cgColor
            line.frame = CGRect(x: 0, y: y, width: drawW, height: 0.5)
            chartContainer.addSublayer(line)
            gridLayers.append(line)
            
            // Price label aligned to the same Y
            let label = makeTextLayer(text: formatPrice(price), font: font, color: Style.priceTextColor)
            let labelH: CGFloat = 14
            label.frame = CGRect(x: drawW + 4,
                                 y: y - labelH / 2,
                                 width: axisW - 4,
                                 height: labelH)
            chartContainer.addSublayer(label)
            priceLabelLayers.append(label)
        }
    }
    
    private func drawCandles() {
        let totalW    = bounds.width
        let totalH    = bounds.height
        let axisW     = Layout.priceAxisWidth
        let drawableW = totalW - axisW
        
        // Candles span the full drawable width
        let count  = CGFloat(candles.count)
        let slotW  = drawableW / count
        let bodyW  = slotW * Layout.candleBodyWidthFraction
        let wickW  = Layout.wickWidthPt
        
        // Candles are price-mapped to the center 2/3 of the view height
        let candleH    = totalH * Layout.candleAreaHeightFraction
        let candleTopY = (totalH - candleH) / 2
        let candleRect = CGRect(x: 0, y: candleTopY, width: drawableW, height: candleH)
        
        let (minP, maxP) = priceRange
        
        for (index, candle) in candles.enumerated() {
            let isBull = candle.close >= candle.open
            
            let slotLeft = CGFloat(index) * slotW
            
            let highY  = yForPrice(candle.high,  in: candleRect, minP: minP, maxP: maxP)
            let lowY   = yForPrice(candle.low,   in: candleRect, minP: minP, maxP: maxP)
            let openY  = yForPrice(candle.open,  in: candleRect, minP: minP, maxP: maxP)
            let closeY = yForPrice(candle.close, in: candleRect, minP: minP, maxP: maxP)
            
            let bodyTop    = min(openY, closeY)
            let bodyBottom = max(openY, closeY)
            let bodyHeight = max(bodyBottom - bodyTop, 1) // at least 1pt
            
            let color = isBull ? Style.bullishColor : Style.bearishColor
            
            let container = CALayer()
            container.frame = CGRect(x: slotLeft, y: 0, width: slotW, height: totalH)
            
            // Wick (high → low)
            let wick = CALayer()
            wick.backgroundColor = color.cgColor
            wick.frame = CGRect(
                x: (slotW - wickW) / 2,
                y: highY,
                width: wickW,
                height: lowY - highY
            )
            container.addSublayer(wick)
            
            // Body
            let body = CALayer()
            body.backgroundColor = color.cgColor
            body.frame = CGRect(
                x: (slotW - bodyW) / 2,
                y: bodyTop,
                width: bodyW,
                height: bodyHeight
            )
            container.addSublayer(body)
            
            chartContainer.addSublayer(container)
            candleLayers.append(container)
        }
    }
    
    private func animateHighLine() {
        guard !candles.isEmpty else { return }
        
        let totalW    = bounds.width
        let totalH    = bounds.height
        let axisW     = Layout.priceAxisWidth
        let drawableW = totalW - axisW
        
        // Y must match the candle coordinate space (center 2/3 of height)
        let candleH    = totalH * Layout.candleAreaHeightFraction
        let candleTopY = (totalH - candleH) / 2
        let candleRect = CGRect(x: 0, y: candleTopY, width: drawableW, height: candleH)
        
        let (minP, maxP) = priceRange
        let highY = yForPrice(maxP, in: candleRect, minP: minP, maxP: maxP)
        
        // Dashed line path (left edge → right edge of drawable area)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: highY))
        path.addLine(to: CGPoint(x: drawableW, y: highY))
        highLineLayer.frame = bounds
        highLineLayer.path  = path.cgPath
        
        // Label badge
        let labelW: CGFloat = axisW - 4
        let labelH: CGFloat = 16
        let labelX = drawableW + 2
        let labelY = highY - labelH / 2
        
        highLabelBadge.frame = CGRect(x: 0, y: 0, width: labelW, height: labelH)
        highLabelText.string = formatPrice(maxP)
        highLabelText.frame  = CGRect(x: 0, y: 1, width: labelW, height: labelH)
        highLabelLayer.frame = CGRect(x: labelX, y: labelY, width: labelW, height: labelH)
        
        // Animate in after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.4)
            CATransaction.setAnimationTimingFunction(
                CAMediaTimingFunction(name: .easeOut)
            )
            self.highLineLayer.opacity  = 1
            self.highLabelLayer.opacity = 1
            CATransaction.commit()
        }
    }
    
    private func makeTextLayer(text: String, font: UIFont, color: UIColor) -> CATextLayer {
        let layer = CATextLayer()
        layer.string          = text
        layer.font            = font as CTFont
        layer.fontSize        = font.pointSize
        layer.foregroundColor = color.cgColor
        layer.contentsScale   = UIScreen.main.scale
        layer.alignmentMode   = .right
        layer.truncationMode  = .none
        return layer
    }
    
    private func formatPrice(_ price: CGFloat) -> String {
        if price >= 1_000 {
            return String(format: "%.0f", price)
        } else if price >= 10 {
            return String(format: "%.2f", price)
        } else {
            return String(format: "%.4f", price)
        }
    }
    
}
