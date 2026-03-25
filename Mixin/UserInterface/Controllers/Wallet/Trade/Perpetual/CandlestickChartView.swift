import UIKit
import MixinServices

final class CandlestickChartView: UIView {
    
    private enum Config {
        
        static let defaultCandleWidth: CGFloat = 6
        static let minCandleWidth: CGFloat = 3
        static let maxCandleWidth: CGFloat = 10
        static let candleGap: CGFloat = 2
        static let priceAreaWidth: CGFloat = 50
        
        static let gridLineCount: Int = 6
        static let gridLineColor = R.color.grid_line()
        static let gridPriceFont: UIFont = .systemFont(ofSize: 8)
        static let gridPriceColor = R.color.text_tertiary()!
        static let yAxisPaddingRatio: Decimal = 0.1 // 10% padding top & bottom
        
        static let bullColor = MarketColor.rising.uiColor
        static let bearColor = MarketColor.falling.uiColor
        
        static let latestPriceLineColor = R.color.text_tertiary()!
        
        enum PriceTag {
            static let font: UIFont = .systemFont(ofSize: 8, weight: .semibold)
            static let borderColor = R.color.price_tag_border()!
            static let backgroundColor = R.color.price_tag_background()!
            static let textColor = R.color.price_tag_text()!
        }
        
        static let crosshairColor = R.color.text_tertiary()!
        static let crosshairThickness = 1 / UIScreen.main.scale
        static let crosshairDotColor = R.color.text_secondary()!
        static let crosshairDotSize = CGSize(width: 10, height: 10)
        static let crosshairDotBorderWidth: CGFloat = 2
        
        static let timeFont: UIFont = .systemFont(ofSize: 12, weight: .medium)
        static let timeColor = R.color.text_quaternary()!
        
    }
    
    private let gridBackgroundView = GridBackgroundView(count: Config.gridLineCount)
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let latestPriceView = LatestPriceIndicatorView()
    private let crosshairView = CrosshairView()
    
    private let bullLayer = CAShapeLayer()
    private let bearLayer = CAShapeLayer()
    
    private let feedback = UISelectionFeedbackGenerator()
    
    private var pinchGesture: UIPinchGestureRecognizer?
    private var candles: [PerpetualCandleViewModel] = []
    
    var currentPrice: Decimal? {
        didSet {
            updateLatestPrice()
        }
    }
    
    private var currentCandleWidth: CGFloat = Config.defaultCandleWidth
    private var lastPinchWidth: CGFloat = Config.defaultCandleWidth
    private var currentMin: Decimal = 0
    private var currentMax: Decimal = 0
    private var isCrosshairActive = false
    private var lastCrosshairIndex: Int = -1
    
    private var rightMostContentOffset: CGPoint {
        CGPoint(
            x: max(0, scrollView.contentSize.width - scrollView.frame.width),
            y: scrollView.contentOffset.y
        )
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        crosshairView.frame = bounds
        updateContentSize()
        updateChart(forceRedraw: true)
    }
    
    func setCandles(_ candles: [PerpetualCandleViewModel], scrollsToLast: Bool) {
        self.candles = candles
        updateContentSize()
        if scrollsToLast {
            scrollView.setContentOffset(rightMostContentOffset, animated: false)
        }
        updateChart(forceRedraw: true)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.numberOfTouches == 2 else {
            return
        }
        switch gesture.state {
        case .began:
            lastPinchWidth = currentCandleWidth
        case .changed:
            let scale = gesture.scale
            var newWidth = lastPinchWidth * scale
            newWidth = max(Config.minCandleWidth, min(Config.maxCandleWidth, newWidth))
            let diff = newWidth - currentCandleWidth
            let isScalingUp = diff > 0
            
            if abs(diff) >= 0.08 {
                let oldStep = currentCandleWidth + Config.candleGap
                let newStep = newWidth + Config.candleGap
                
                let locationX = gesture.location(in: scrollView).x
                let newLocationX = locationX / oldStep * newStep
                let shift = newLocationX - locationX
                
                currentCandleWidth = newWidth
                updateContentSize()
                
                let newOffset = CGPoint(
                    x: scrollView.contentOffset.x + shift,
                    y: scrollView.contentOffset.y
                )
                if isScalingUp || newOffset.x >= rightMostContentOffset.x {
                    scrollView.contentOffset = newOffset
                }
                
                updateChart(forceRedraw: true)
            }
        default:
            break
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: scrollView)
        let step = currentCandleWidth + Config.candleGap
        let index = Int(max(0, min(CGFloat(candles.count - 1), round(location.x / step - 0.5))))
        switch gesture.state {
        case .began:
            isCrosshairActive = true
            scrollView.isScrollEnabled = false
            pinchGesture?.isEnabled = false
            latestPriceView.isHidden = true
            crosshairView.isHidden = false
            feedback.prepare()
            updateCrosshair(location: location, index: index)
        case .changed:
            if index != lastCrosshairIndex {
                feedback.selectionChanged()
            }
            updateCrosshair(location: location, index: index)
        case .ended, .cancelled, .failed:
            isCrosshairActive = false
            scrollView.isScrollEnabled = true
            pinchGesture?.isEnabled = true
            crosshairView.isHidden = true
            updateLatestPrice()
        default:
            break
        }
    }
    
    private func loadSubviews() {
        backgroundColor = R.color.background()
        addSubview(gridBackgroundView)
        gridBackgroundView.snp.makeEdgesEqualToSuperview()
        gridBackgroundView.clipsToBounds = true
        
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = true
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.trailing.equalToSuperview().offset(-Config.priceAreaWidth)
        }
        
        scrollView.addSubview(contentView)
        bullLayer.fillColor = Config.bullColor.cgColor
        bullLayer.strokeColor = Config.bullColor.cgColor
        contentView.layer.addSublayer(bullLayer)
        
        bearLayer.fillColor = Config.bearColor.cgColor
        bearLayer.strokeColor = Config.bearColor.cgColor
        contentView.layer.addSublayer(bearLayer)
        
        latestPriceView.isUserInteractionEnabled = false
        addSubview(latestPriceView)
        latestPriceView.isHidden = true
        
        crosshairView.isUserInteractionEnabled = false
        addSubview(crosshairView)
        crosshairView.isHidden = true
        
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.3
        addGestureRecognizer(longPress)
    }
    
    private func updateContentSize() {
        let step = currentCandleWidth + Config.candleGap
        let totalWidth = CGFloat(candles.count) * step
        scrollView.contentSize = CGSize(
            width: max(totalWidth, bounds.width),
            height: bounds.height
        )
        contentView.frame = CGRect(
            x: 0,
            y: 0,
            width: scrollView.contentSize.width,
            height: bounds.height
        )
    }
    
    private func updateChart(forceRedraw: Bool) {
        guard !candles.isEmpty else {
            return
        }
        
        let step = currentCandleWidth + Config.candleGap
        let visibleStartX = max(0, scrollView.contentOffset.x)
        let visibleEndX = visibleStartX + bounds.width
        
        let startIndex = max(0, Int(visibleStartX / step))
        let endIndex = min(candles.count - 1, Int(visibleEndX / step) + 1)
        
        guard startIndex <= endIndex else {
            return
        }
        
        let visibleCandles = candles[startIndex...endIndex]
        
        var minVal: Decimal = NSDecimalNumber.maximum as Decimal
        var maxVal: Decimal = -minVal
        
        for candle in visibleCandles {
            let high = candle.high as Decimal
            let low = candle.low as Decimal
            if high > maxVal { maxVal = high }
            if low < minVal { minVal = low }
        }
        
        // Add padding
        if minVal == maxVal {
            minVal -= 1; maxVal += 1
        } else {
            let pad = (maxVal - minVal) * Config.yAxisPaddingRatio
            minVal -= pad; maxVal += pad
        }
        
        // Optimization: Skip heavy redraw if Y scale hasn't changed.
        if !forceRedraw && minVal == currentMin && maxVal == currentMax {
            updateLatestPrice()
            return
        }
        
        currentMin = minVal
        currentMax = maxVal
        
        redrawPaths()
        gridBackgroundView.updateLabels(minVal: minVal, maxVal: maxVal)
        updateLatestPrice()
    }
    
    private func redrawPaths() {
        let yRange = ((currentMax - currentMin) as NSDecimalNumber).doubleValue
        let viewHeight = bounds.height
        
        func y(price: NSDecimalNumber) -> CGFloat {
            let diff = (currentMax as NSDecimalNumber).subtracting(price)
            return diff.doubleValue / yRange * viewHeight
        }
        
        let bullPath = CGMutablePath()
        let bearPath = CGMutablePath()
        let step = currentCandleWidth + Config.candleGap
        
        for (i, candle) in candles.enumerated() {
            let xCenter = CGFloat(i) * step + step / 2.0
            let bodyX = xCenter - currentCandleWidth / 2.0
            
            let openY = y(price: candle.open)
            let closeY = y(price: candle.close)
            let highY = y(price: candle.high)
            let lowY = y(price: candle.low)
            
            let isBull = candle.close.compare(candle.open) != .orderedAscending
            let path = isBull ? bullPath : bearPath
            
            // Wick
            path.move(to: CGPoint(x: xCenter, y: highY))
            path.addLine(to: CGPoint(x: xCenter, y: lowY))
            
            // Body
            let rect = CGRect(
                x: bodyX,
                y: min(openY, closeY),
                width: currentCandleWidth,
                height: max(abs(openY - closeY), 1.0)
            )
            path.addRect(rect)
        }
        
        bullLayer.path = bullPath
        bearLayer.path = bearPath
    }
    
    private func updateCrosshair(location: CGPoint, index: Int) {
        lastCrosshairIndex = index
        let candle = candles[index]
        let step = currentCandleWidth + Config.candleGap
        let xInContent = CGFloat(index) * step + step / 2.0
        let xOnScreen = xInContent - scrollView.contentOffset.x
        
        let priceRange = currentMin - currentMax
        let p = Decimal(location.y) * priceRange / Decimal(bounds.height) + currentMax
        let price = CurrencyFormatter.localizedString(
            from: p,
            format: .fiatMoneyPrice,
            sign: .never
        )
        crosshairView.update(
            x: xOnScreen,
            y: location.y,
            time: candle.time,
            price: price,
            viewSize: bounds.size,
        )
    }
    
    private func updateLatestPrice() {
        guard let price = currentPrice, !isCrosshairActive else {
            latestPriceView.isHidden = true
            return
        }
        
        let step = currentCandleWidth + Config.candleGap
        let lastX = CGFloat(candles.count - 1) * step
        let startX = scrollView.contentOffset.x
        
        if lastX < startX || lastX > startX + scrollView.frame.width {
            latestPriceView.isHidden = true
        } else {
            latestPriceView.isHidden = false
            let yRange = (currentMax - currentMin) as NSDecimalNumber
            let yPos: CGFloat
            if yRange == 0 {
                yPos = bounds.height / 2
            } else {
                let diff = (currentMax - price) as NSDecimalNumber
                yPos = diff.doubleValue / yRange.doubleValue * bounds.height
            }
            let price = CurrencyFormatter.localizedString(
                from: price,
                format: .fiatMoneyPrice,
                sign: .never
            )
            latestPriceView.update(
                y: yPos,
                price: price,
                viewWidth: bounds.width
            )
        }
    }
    
}

extension CandlestickChartView: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateChart(forceRedraw: false)
    }
    
}

extension CandlestickChartView {
    
    private final class GridBackgroundView: UIStackView {
        
        private var labels: [UILabel] = []
        
        init(count: Int) {
            super.init(frame: CGRect(x: 0, y: 0, width: 296, height: 10))
            axis = .vertical
            distribution = .equalSpacing
            for _ in 0..<count {
                let row = UIView()
                row.backgroundColor = R.color.background()
                addArrangedSubview(row)
                
                let line = UIView()
                line.backgroundColor = Config.gridLineColor
                row.addSubview(line)
                line.snp.makeConstraints { make in
                    make.leading.centerY.equalToSuperview()
                    make.height.equalTo(1 / UIScreen.main.scale)
                }
                
                let label = UILabel()
                label.font = Config.gridPriceFont
                label.textColor = Config.gridPriceColor
                label.textAlignment = .center
                row.addSubview(label)
                label.snp.makeConstraints { make in
                    make.top.trailing.bottom.equalToSuperview()
                    make.leading.equalTo(line.snp.trailing)
                    make.width.equalTo(Config.priceAreaWidth)
                }
                labels.append(label)
            }
        }
        
        required init(coder: NSCoder) {
            fatalError("Storyboard/Xib not supported")
        }
        
        func updateLabels(minVal: Decimal, maxVal: Decimal) {
            let range = maxVal - minVal
            for (i, label) in labels.enumerated() {
                let fraction = 1 - (Decimal(i) / Decimal(Config.gridLineCount - 1))
                label.text = CurrencyFormatter.localizedString(
                    from: minVal + range * fraction,
                    format: .fiatMoneyPrice,
                    sign: .never
                )
            }
        }
        
    }
    
    private final class LatestPriceIndicatorView: UIView {
        
        private let lineLayer = CAShapeLayer()
        private let label = InsetLabel()
        private let height: CGFloat = 20
        
        private var lastViewWidth: CGFloat?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            lineLayer.strokeColor = Config.latestPriceLineColor.cgColor
            lineLayer.lineWidth = 1
            lineLayer.lineDashPattern = [2.4, 2.4]
            layer.addSublayer(lineLayer)
            
            label.font = Config.PriceTag.font
            label.textColor = Config.PriceTag.textColor
            label.backgroundColor = Config.PriceTag.backgroundColor
            label.layer.borderColor = Config.PriceTag.borderColor.cgColor
            label.layer.borderWidth = 1
            label.layer.cornerRadius = 2
            label.layer.masksToBounds = true
            label.textAlignment = .center
            label.contentInset = UIEdgeInsets(top: 1, left: 2, bottom: 1, right: 2)
            addSubview(label)
        }
        
        required init?(coder: NSCoder) {
            fatalError("Storyboard/Xib not supported")
        }
        
        func update(y: CGFloat, price: String, viewWidth: CGFloat) {
            frame = CGRect(
                x: 0,
                y: y - height / 2,
                width: viewWidth,
                height: height
            )
            
            if viewWidth != lastViewWidth {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: height / 2))
                path.addLine(
                    to: CGPoint(x: viewWidth - Config.priceAreaWidth, y: height / 2)
                )
                lineLayer.path = path
                lastViewWidth = viewWidth
            }
            
            label.text = price
            label.sizeToFit()
            label.center = CGPoint(
                x: viewWidth - Config.priceAreaWidth / 2,
                y: round(height / 2),
            )
        }
        
    }
    
    private final class CrosshairView: UIView {
        
        private let vLine = UIView()
        private let hLine = UIView()
        private let dot = UIView()
        private let timeLabel = UILabel()
        private let priceLabel = InsetLabel()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            vLine.backgroundColor = Config.crosshairColor
            hLine.backgroundColor = Config.crosshairColor
            addSubview(vLine)
            addSubview(hLine)
            
            dot.backgroundColor = Config.crosshairDotColor
            dot.layer.borderColor = R.color.background()!.cgColor
            dot.layer.borderWidth = 2
            dot.layer.cornerRadius = Config.crosshairDotSize.width / 2
            dot.layer.masksToBounds = true
            addSubview(dot)
            
            timeLabel.font = Config.timeFont
            timeLabel.textColor = Config.timeColor
            timeLabel.backgroundColor = R.color.background()
            addSubview(timeLabel)
            
            priceLabel.font = Config.PriceTag.font
            priceLabel.textColor = Config.PriceTag.textColor
            priceLabel.backgroundColor = Config.PriceTag.backgroundColor
            priceLabel.layer.borderColor = Config.PriceTag.borderColor.cgColor
            priceLabel.layer.borderWidth = 1
            priceLabel.layer.cornerRadius = 2
            priceLabel.layer.masksToBounds = true
            priceLabel.textAlignment = .center
            priceLabel.contentInset = UIEdgeInsets(top: 1, left: 2, bottom: 1, right: 2)
            addSubview(priceLabel)
        }
        
        required init?(coder: NSCoder) {
            fatalError("Storyboard/Xib not supported")
        }
        
        func update(
            x: CGFloat,
            y: CGFloat,
            time: String,
            price: String,
            viewSize: CGSize,
        ) {
            vLine.frame = CGRect(
                x: x,
                y: 0,
                width: Config.crosshairThickness,
                height: viewSize.height
            )
            hLine.frame = CGRect(
                x: 0,
                y: y,
                width: viewSize.width - Config.priceAreaWidth,
                height: Config.crosshairThickness
            )
            dot.frame = CGRect(
                x: x - Config.crosshairDotSize.width / 2,
                y: y - Config.crosshairDotSize.height / 2,
                width: Config.crosshairDotSize.width,
                height: Config.crosshairDotSize.height
            )
            
            timeLabel.text = time
            timeLabel.sizeToFit()
            timeLabel.center = CGPoint(x: x, y: timeLabel.bounds.height / 2)
            if timeLabel.frame.minX < 0 {
                timeLabel.frame.origin.x = 0
            } else if timeLabel.frame.maxX > viewSize.width {
                timeLabel.frame.origin.x = viewSize.width - timeLabel.bounds.width
            }
            
            priceLabel.text = price
            priceLabel.sizeToFit()
            priceLabel.center = CGPoint(
                x: viewSize.width - Config.priceAreaWidth / 2,
                y: round(y),
            )
        }
        
    }
    
}
