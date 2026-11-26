import UIKit
import MixinServices

final class CandlestickChartView: UIView {
    
    private enum Config {
        static let plotTop: CGFloat = 8
        static let plotBottomInset: CGFloat = 24
        static let axisFont: UIFont = .systemFont(ofSize: 11)
        static let gridLineCount = 4
        static let gridDashLengths: [CGFloat] = [4, 4]
        static let timeBottomOffset: CGFloat = 6
        static let timeMinGap: CGFloat = 8
        
        static let cardBackgroundColor = UIColor(red: 0x3A / 255.0, green: 0x3A / 255.0, blue: 0x3C / 255.0, alpha: 0.94)
        static let cardTitleColor = UIColor(red: 0xAE / 255.0, green: 0xAE / 255.0, blue: 0xB2 / 255.0, alpha: 1.0)
        static let cardValueColor = UIColor.white
        static let cardCornerRadius: CGFloat = 8
        static let cardPadH: CGFloat = 8
        static let cardPadV: CGFloat = 6
        static let cardColumnGap: CGFloat = 8
        static let cardRowSpacing: CGFloat = 1
        static let cardChangeGap: CGFloat = 4
        static let cardCrosshairGap: CGFloat = 8
    }
    
    private static let intradayAxisDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()
    
    private static let dailyAxisDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let intradayDetailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMdjmm")
        return formatter
    }()
    
    private static let dailyDetailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        return formatter
    }()
    
    var viewportState: CandleChartViewportState {
        didSet {
            if !isApplyingConfiguration && oldValue !== viewportState {
                syncLayoutAndRange(animated: false)
            }
        }
    }
    
    var timeFrame: PerpetualTimeFrame = .oneMinute {
        didSet {
            if !isApplyingConfiguration && oldValue != timeFrame {
                viewportState.resetAxisWidth()
                syncLayoutAndRange(animated: false)
            }
        }
    }
    
    var labels: CandleChartLabels = .default {
        didSet {
            if oldValue != labels {
                setNeedsDisplay()
            }
        }
    }
    
    var priceFormatMode: CandlePriceFormatMode = .decimal(priceScale: nil) {
        didSet {
            if !isApplyingConfiguration {
                viewportState.resetAxisWidth()
                syncLayoutAndRange(animated: false)
            }
        }
    }
    
    var latestPrice: Decimal? {
        didSet {
            guard !isApplyingConfiguration, oldValue != latestPrice else {
                return
            }
            updatePriceRange(animated: isUserInteractionEnabled)
            setNeedsDisplay()
        }
    }
    
    // Transitional alias for Phase 1 callers
    var currentPrice: Decimal? {
        get { latestPrice }
        set { latestPrice = newValue }
    }
    
    private let rangeAnimator = PriceRangeAnimator()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private lazy var chartGestureRecognizer = CandleChartGestureRecognizer(target: nil, action: nil)
    
    private var lastLayoutSize: CGSize = .zero
    private var isApplyingConfiguration = false
    
    override init(frame: CGRect) {
        self.viewportState = CandleChartViewportState()
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        self.viewportState = CandleChartViewportState()
        super.init(coder: coder)
        commonInit()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        rangeAnimator.stopAnimation()
        chartGestureRecognizer.stopFling()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastLayoutSize {
            lastLayoutSize = bounds.size
            syncLayoutAndRange(animated: false)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setNeedsDisplay()
        }
    }
    
    func configure(
        candles: [PerpetualCandleViewModel],
        timeFrame: PerpetualTimeFrame,
        latestPrice: Decimal?,
        priceFormatMode: CandlePriceFormatMode? = nil,
        viewportState: CandleChartViewportState? = nil,
        animated: Bool = true
    ) {
        isApplyingConfiguration = true
        let didSwapState = viewportState != nil && viewportState !== self.viewportState
        if let viewportState, viewportState !== self.viewportState {
            self.viewportState = viewportState
        } else if timeFrame != self.timeFrame {
            self.viewportState.resetAxisWidth()
        }
        self.timeFrame = timeFrame
        if let priceFormatMode {
            let modeChanged = !Self.isSameFormatMode(self.priceFormatMode, priceFormatMode)
            self.priceFormatMode = priceFormatMode
            if modeChanged && !didSwapState {
                self.viewportState.resetAxisWidth()
            }
        }
        self.latestPrice = latestPrice
        self.viewportState.updateCandles(candles, isRegularWidth: isRegularWidth)
        isApplyingConfiguration = false
        syncLayoutAndRange(animated: animated)
    }
    
    private static func isSameFormatMode(_ lhs: CandlePriceFormatMode, _ rhs: CandlePriceFormatMode) -> Bool {
        switch (lhs, rhs) {
        case let (.decimal(l), .decimal(r)):
            return l == r
        case let (.currencyStyle(l), .currencyStyle(r)):
            return l == r
        default:
            return false
        }
    }
    
    func snapPriceRangeWithoutAnimation() {
        syncLayoutAndRange(animated: false)
    }
    
    // Transitional compile bridge for Phase 1; Phase 2 migrates callers to `configure(...)`.
    func setCandles(
        _ candles: [PerpetualCandleViewModel],
        priceFormatStyle: Decimal.FormatStyle.Currency,
        scrollsToLast: Bool
    ) {
        priceFormatMode = .currencyStyle(priceFormatStyle)
        viewportState.updateCandles(candles, isRegularWidth: isRegularWidth)
        if scrollsToLast {
            viewportState.scrollToLatest()
        }
        syncLayoutAndRange(animated: isUserInteractionEnabled)
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        let backgroundColor = (R.color.background() ?? .systemBackground).resolvedColor(with: traitCollection)
        context.setFillColor(backgroundColor.cgColor)
        context.fill(bounds)
        
        let candles = viewportState.candles
        guard !candles.isEmpty,
              bounds.width > 0,
              bounds.height > Config.plotTop + Config.plotBottomInset
        else {
            return
        }
        
        // Layer 1: Plot geometry & monotonic axisWidth
        let plotTop = Config.plotTop
        let plotBottom = bounds.height - Config.plotBottomInset
        let plotHeight = max(1, plotBottom - plotTop)
        let axisWidth = currentAxisWidth()
        let plotWidth = max(1, bounds.width - axisWidth)
        let axisTextX = plotWidth + 8
        
        if abs(viewportState.plotWidth - plotWidth) > 0.5 {
            viewportState.updateLayout(plotWidth: plotWidth, isRegularWidth: isRegularWidth)
        }
        
        guard let visibleIndices = viewportState.visibleIndices else {
            return
        }
        
        let range: PriceRange
        if let currentRange = rangeAnimator.current {
            range = currentRange
        } else if let immediate = PriceRangeAnimator.visiblePriceRange(
            candles: candles,
            visibleIndices: visibleIndices,
            latestPrice: latestPriceDouble
        ) {
            rangeAnimator.snap(to: immediate)
            range = immediate
        } else {
            return
        }
        
        let textAssistColor = (R.color.text_tertiary() ?? .secondaryLabel).resolvedColor(with: traitCollection)
        let risingColor = MarketColor.rising.uiColor.resolvedColor(with: traitCollection)
        let fallingColor = MarketColor.falling.uiColor.resolvedColor(with: traitCollection)
        
        let latestDecimal = latestPrice
        let latestDouble = latestPriceDouble
        let latestY = latestDouble.map { yCoordinate(for: $0, range: range, plotBottom: plotBottom, plotHeight: plotHeight) }
        let showLatest = latestY.map { $0 >= plotTop && $0 <= plotBottom } ?? false
        let sampleHeight = ("0" as NSString).size(withAttributes: [.font: Config.axisFont]).height
        let latestTagHeight = sampleHeight + 4
        
        // Layer 2: 4 horizontal dashed grid lines & anti-collision Y-axis labels
        let priceSpan = range.max - range.min
        let gridStrokeColor = textAssistColor.withAlphaComponent(0.3).cgColor
        let axisAttributes: [NSAttributedString.Key: Any] = [
            .font: Config.axisFont,
            .foregroundColor: textAssistColor,
        ]
        
        for i in 0..<Config.gridLineCount {
            let fraction = CGFloat(i) / CGFloat(Config.gridLineCount - 1)
            let y = plotTop + plotHeight * fraction
            
            context.saveGState()
            context.setStrokeColor(gridStrokeColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: Config.gridDashLengths)
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: plotWidth, y: y))
            context.strokePath()
            context.restoreGState()
            
            let price = range.max - priceSpan * Double(fraction)
            let priceText = formatPrice(Decimal(price))
            let labelSize = (priceText as NSString).size(withAttributes: axisAttributes)
            var labelCenterY = y
            if showLatest, let latestY {
                let minGap = (latestTagHeight + labelSize.height) / 2 + 2
                if abs(labelCenterY - latestY) < minGap {
                    labelCenterY = (labelCenterY < latestY) ? (latestY - minGap) : (latestY + minGap)
                }
            }
            let labelTop = labelCenterY - labelSize.height / 2
            let labelBottom = labelCenterY + labelSize.height / 2
            if labelTop >= 0 && labelBottom <= bounds.height {
                (priceText as NSString).draw(
                    at: CGPoint(x: axisTextX, y: labelTop),
                    withAttributes: axisAttributes
                )
            }
        }
        
        // Layer 3: Rounded candles using standard circular-arc CGPath
        context.saveGState()
        context.clip(to: CGRect(x: 0, y: plotTop, width: plotWidth, height: plotHeight))
        
        let step = viewportState.step
        let bodyWidth = step * 0.7
        let wickWidth = min(max(bodyWidth * 0.3, 1.5), 3.0)
        
        for index in visibleIndices {
            let candle = candles[index]
            let isBull = candle.close.compare(candle.open) != .orderedAscending
            let fillColor = (isBull ? risingColor : fallingColor).cgColor
            context.setFillColor(fillColor)
            
            let centerX = viewportState.centerX(forIndex: index)
            let highY = yCoordinate(for: candle.high.doubleValue, range: range, plotBottom: plotBottom, plotHeight: plotHeight)
            let lowY = yCoordinate(for: candle.low.doubleValue, range: range, plotBottom: plotBottom, plotHeight: plotHeight)
            let openY = yCoordinate(for: candle.open.doubleValue, range: range, plotBottom: plotBottom, plotHeight: plotHeight)
            let closeY = yCoordinate(for: candle.close.doubleValue, range: range, plotBottom: plotBottom, plotHeight: plotHeight)
            
            let wickTop = min(highY, lowY)
            let wickHeight = max(abs(lowY - highY), wickWidth)
            let wickRect = CGRect(x: centerX - wickWidth / 2, y: wickTop, width: wickWidth, height: wickHeight)
            let wickRadius = safeCornerRadius(
                min(wickWidth / 2, wickRect.width / 2, wickRect.height / 2),
                for: wickRect
            )
            if wickRect.width > 0, wickRect.height > 0 {
                let wickPath = CGPath(roundedRect: wickRect, cornerWidth: wickRadius, cornerHeight: wickRadius, transform: nil)
                context.addPath(wickPath)
                context.fillPath()
            }
            
            let bodyTop = min(openY, closeY)
            let bodyHeight = max(abs(openY - closeY), wickWidth)
            let bodyRect = CGRect(x: centerX - bodyWidth / 2, y: bodyTop, width: bodyWidth, height: bodyHeight)
            let rawBodyRadius = min(bodyWidth / 3, bodyHeight / 2)
            let bodyRadius = safeCornerRadius(
                min(rawBodyRadius, bodyRect.width / 2, bodyRect.height / 2),
                for: bodyRect
            )
            if bodyRect.width > 0, bodyRect.height > 0 {
                let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil)
                context.addPath(bodyPath)
                context.fillPath()
            }
        }
        context.restoreGState()
        
        // Layer 4: Latest price solid line & capsule tag (stays visible during selection)
        if showLatest, let latestY, let latestDecimal, let lastCandle = candles.last {
            let isBull = latestDecimal >= lastCandle.open.decimalValue
            let latestColor = isBull ? risingColor : fallingColor
            
            context.saveGState()
            context.setStrokeColor(latestColor.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: 0, y: latestY))
            context.addLine(to: CGPoint(x: plotWidth, y: latestY))
            context.strokePath()
            
            let latestText = formatPrice(latestDecimal)
            let latestAttributes: [NSAttributedString.Key: Any] = [
                .font: Config.axisFont,
                .foregroundColor: latestColor,
            ]
            let textSize = (latestText as NSString).size(withAttributes: latestAttributes)
            let padH: CGFloat = 6
            let padV: CGFloat = 2
            let tagHeight = textSize.height + padV * 2
            let tagWidth = textSize.width + padH * 2
            let tagRect = CGRect(
                x: axisTextX - padH,
                y: latestY - tagHeight / 2,
                width: tagWidth,
                height: tagHeight
            )
            let tagRadius = safeCornerRadius(tagHeight / 2, for: tagRect)
            let tagPath = CGPath(roundedRect: tagRect, cornerWidth: tagRadius, cornerHeight: tagRadius, transform: nil)
            context.setFillColor(latestColor.withAlphaComponent(0.12).cgColor)
            context.addPath(tagPath)
            context.fillPath()
            
            (latestText as NSString).draw(
                at: CGPoint(x: axisTextX, y: latestY - textSize.height / 2),
                withAttributes: latestAttributes
            )
            context.restoreGState()
        }
        
        // Layer 5: Bottom first/last timestamps with overlap guard
        let timeY = plotBottom + Config.timeBottomOffset
        let firstTimeIndex = min(
            max(visibleIndices.lowerBound, Int(ceil(viewportState.end - viewportState.visibleCount))),
            visibleIndices.upperBound
        )
        let lastTimeIndex = visibleIndices.upperBound
        let startTimeText = formatAxisTime(candles[firstTimeIndex].timestamp)
        let startTimeSize = (startTimeText as NSString).size(withAttributes: axisAttributes)
        (startTimeText as NSString).draw(at: CGPoint(x: 0, y: timeY), withAttributes: axisAttributes)
        
        if firstTimeIndex < lastTimeIndex {
            let endTimeText = formatAxisTime(candles[lastTimeIndex].timestamp)
            let endTimeSize = (endTimeText as NSString).size(withAttributes: axisAttributes)
            let endX = max(startTimeSize.width + Config.timeMinGap, plotWidth - endTimeSize.width)
            (endTimeText as NSString).draw(at: CGPoint(x: endX, y: timeY), withAttributes: axisAttributes)
        }
        
        // Layer 6: Crosshair (locked to closeY, no dot) & 5-row detail card
        if let selectedIndex = viewportState.selectedIndex,
           selectedIndex >= 0,
           selectedIndex < candles.count
        {
            drawSelection(
                in: context,
                candle: candles[selectedIndex],
                index: selectedIndex,
                range: range,
                plotTop: plotTop,
                plotBottom: plotBottom,
                plotHeight: plotHeight,
                plotWidth: plotWidth,
                textAssistColor: textAssistColor,
                risingColor: risingColor,
                fallingColor: fallingColor
            )
        }
    }
    
    private var isRegularWidth: Bool {
        traitCollection.horizontalSizeClass == .regular
    }
    
    private var latestPriceDouble: Double? {
        guard let latestPrice, !latestPrice.isNaN else {
            return nil
        }
        return NSDecimalNumber(decimal: latestPrice).doubleValue
    }
    
    private func commonInit() {
        contentMode = .redraw
        backgroundColor = R.color.background()
        
        rangeAnimator.onUpdate = { [weak self] in
            self?.setNeedsDisplay()
        }
        
        chartGestureRecognizer.chartDelegate = self
        addGestureRecognizer(chartGestureRecognizer)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMarketColorAppearanceChange),
            name: AppGroupUserDefaults.User.marketColorAppearanceDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleMarketColorAppearanceChange() {
        setNeedsDisplay()
    }
    
    private func currentAxisWidth() -> CGFloat {
        guard !viewportState.candles.isEmpty || latestPrice != nil else {
            return CandlePriceFormatter.minimumAxisWidth
        }
        let measured = CandlePriceFormatter.measureAxisWidth(
            candles: viewportState.candles,
            latestPrice: latestPrice,
            mode: priceFormatMode,
            font: Config.axisFont
        )
        return viewportState.updateAxisWidth(measuredWidth: measured)
    }
    
    private func syncLayoutAndRange(animated: Bool) {
        guard bounds.width > 0 else {
            setNeedsDisplay()
            return
        }
        let axisWidth = currentAxisWidth()
        let plotWidth = max(1, bounds.width - axisWidth)
        viewportState.updateLayout(plotWidth: plotWidth, isRegularWidth: isRegularWidth)
        updatePriceRange(animated: animated)
        setNeedsDisplay()
    }
    
    private func updatePriceRange(animated: Bool) {
        guard let visibleIndices = viewportState.visibleIndices,
              let target = PriceRangeAnimator.visiblePriceRange(
                  candles: viewportState.candles,
                  visibleIndices: visibleIndices,
                  latestPrice: latestPriceDouble
              )
        else {
            rangeAnimator.reset()
            return
        }
        if animated {
            rangeAnimator.update(target: target, hold: viewportState.isScrolling)
        } else {
            rangeAnimator.snap(to: target)
        }
    }
    
    private func yCoordinate(
        for price: Double,
        range: PriceRange,
        plotBottom: CGFloat,
        plotHeight: CGFloat
    ) -> CGFloat {
        let span = range.max - range.min
        guard span > 0 else {
            return plotBottom - plotHeight / 2
        }
        return plotBottom - CGFloat((price - range.min) / span) * plotHeight
    }
    
    private func safeCornerRadius(_ radius: CGFloat, for rect: CGRect) -> CGFloat {
        let maxW = rect.width * 0.4999
        let maxH = rect.height * 0.4999
        return max(0, min(radius, maxW, maxH))
    }
    
    private func formatPrice(_ value: Decimal) -> String {
        CandlePriceFormatter.format(
            value,
            mode: priceFormatMode,
            candles: viewportState.candles
        )
    }
    
    private func formatAxisTime(_ timestampMillis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestampMillis) / 1000)
        let formatter: DateFormatter = timeFrame.usesDateOnlyFormat
            ? Self.dailyAxisDateFormatter
            : Self.intradayAxisDateFormatter
        return formatter.string(from: date)
    }
    
    private func formatDetailDate(_ timestampMillis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestampMillis) / 1000)
        let formatter: DateFormatter = timeFrame.usesDateOnlyFormat
            ? Self.dailyDetailDateFormatter
            : Self.intradayDetailDateFormatter
        return formatter.string(from: date)
    }
    
    private func drawSelection(
        in context: CGContext,
        candle: PerpetualCandleViewModel,
        index: Int,
        range: PriceRange,
        plotTop: CGFloat,
        plotBottom: CGFloat,
        plotHeight: CGFloat,
        plotWidth: CGFloat,
        textAssistColor: UIColor,
        risingColor: UIColor,
        fallingColor: UIColor
    ) {
        let centerX = viewportState.centerX(forIndex: index)
        let rawCloseY = yCoordinate(
            for: candle.close.doubleValue,
            range: range,
            plotBottom: plotBottom,
            plotHeight: plotHeight
        )
        let closeY = max(plotTop, min(plotBottom, rawCloseY))
        
        // Crosshair solid lines (locked to closeY, no dot)
        context.saveGState()
        context.setStrokeColor(textAssistColor.withAlphaComponent(0.7).cgColor)
        context.setLineWidth(1)
        if centerX >= 0 && centerX <= plotWidth {
            context.move(to: CGPoint(x: centerX, y: plotTop))
            context.addLine(to: CGPoint(x: centerX, y: plotBottom))
        }
        context.move(to: CGPoint(x: 0, y: closeY))
        context.addLine(to: CGPoint(x: plotWidth, y: closeY))
        context.strokePath()
        context.restoreGState()
        
        // 5-row detail card
        let openDecimal = candle.open.decimalValue
        let closeDecimal = candle.close.decimalValue
        let isRising = closeDecimal >= openDecimal
        let changeColor = isRising ? risingColor : fallingColor
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: Config.axisFont,
            .foregroundColor: Config.cardTitleColor,
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: Config.axisFont,
            .foregroundColor: Config.cardValueColor,
        ]
        let changeAttributes: [NSAttributedString.Key: Any] = [
            .font: Config.axisFont,
            .foregroundColor: changeColor,
        ]
        
        let changeText = CandlePriceFormatter.formatChangePercentage(open: openDecimal, close: closeDecimal)
        let rows: [(title: String, value: String, suffix: String?)] = [
            (labels.open, formatPrice(openDecimal), nil),
            (labels.close, formatPrice(closeDecimal), changeText),
            (labels.high, formatPrice(candle.high.decimalValue), nil),
            (labels.low, formatPrice(candle.low.decimalValue), nil),
            (labels.date, formatDetailDate(candle.timestamp), nil),
        ]
        
        var maxTitleWidth: CGFloat = 0
        var maxValueWidth: CGFloat = 0
        var rowHeights: [CGFloat] = []
        rowHeights.reserveCapacity(rows.count)
        
        for row in rows {
            let titleSize = (row.title as NSString).size(withAttributes: titleAttributes)
            let valueSize = (row.value as NSString).size(withAttributes: valueAttributes)
            var totalValueWidth = valueSize.width
            var rowHeight = max(titleSize.height, valueSize.height)
            if let suffix = row.suffix {
                let suffixSize = (suffix as NSString).size(withAttributes: changeAttributes)
                totalValueWidth += Config.cardChangeGap + suffixSize.width
                rowHeight = max(rowHeight, suffixSize.height)
            }
            maxTitleWidth = max(maxTitleWidth, titleSize.width)
            maxValueWidth = max(maxValueWidth, totalValueWidth)
            rowHeights.append(rowHeight)
        }
        
        let cardWidth = Config.cardPadH * 2 + maxTitleWidth + Config.cardColumnGap + maxValueWidth
        let totalRowHeight = rowHeights.reduce(0, +)
        let cardHeight = Config.cardPadV * 2 + totalRowHeight + Config.cardRowSpacing * CGFloat(max(0, rows.count - 1))
        
        let cardY = plotTop
        let leftX = centerX - Config.cardCrosshairGap - cardWidth
        let rightX = centerX + Config.cardCrosshairGap
        let fitsLeft = leftX >= 0
        let fitsRight = rightX + cardWidth <= bounds.width
        let preferLeft = centerX > plotWidth / 2
        
        let cardX: CGFloat
        if preferLeft && fitsLeft {
            cardX = leftX
        } else if !preferLeft && fitsRight {
            cardX = rightX
        } else if fitsLeft {
            cardX = leftX
        } else if fitsRight {
            cardX = rightX
        } else {
            cardX = preferLeft ? 0 : max(0, bounds.width - cardWidth)
        }
        
        let cardRect = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)
        let cardRadius = safeCornerRadius(Config.cardCornerRadius, for: cardRect)
        let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)
        
        context.saveGState()
        context.setFillColor(Config.cardBackgroundColor.cgColor)
        context.addPath(cardPath)
        context.fillPath()
        
        let titleRightEdge = cardX + Config.cardPadH + maxTitleWidth
        let valueLeftEdge = titleRightEdge + Config.cardColumnGap
        var currentY = cardY + Config.cardPadV
        
        for (index, row) in rows.enumerated() {
            let titleSize = (row.title as NSString).size(withAttributes: titleAttributes)
            let valueSize = (row.value as NSString).size(withAttributes: valueAttributes)
            
            (row.title as NSString).draw(
                at: CGPoint(x: titleRightEdge - titleSize.width, y: currentY),
                withAttributes: titleAttributes
            )
            (row.value as NSString).draw(
                at: CGPoint(x: valueLeftEdge, y: currentY),
                withAttributes: valueAttributes
            )
            if let suffix = row.suffix {
                (suffix as NSString).draw(
                    at: CGPoint(x: valueLeftEdge + valueSize.width + Config.cardChangeGap, y: currentY),
                    withAttributes: changeAttributes
                )
            }
            currentY += rowHeights[index] + Config.cardRowSpacing
        }
        context.restoreGState()
    }
    
}

extension CandlestickChartView: CandleChartGestureRecognizerDelegate {
    
    func candleChartGestureDidStartInteraction(_ recognizer: CandleChartGestureRecognizer) {
        // Fling cancellation is handled inside gesture recognizer before state transitions
    }
    
    func candleChartGesture(_ recognizer: CandleChartGestureRecognizer, didChangeScrolling isScrolling: Bool) {
        viewportState.isScrolling = isScrolling
        updatePriceRange(animated: true)
        setNeedsDisplay()
    }
    
    func candleChartGesture(_ recognizer: CandleChartGestureRecognizer, didScrollBy deltaX: CGFloat) -> Bool {
        let moved = viewportState.scrollByPx(deltaX)
        updatePriceRange(animated: true)
        setNeedsDisplay()
        return moved
    }
    
    func candleChartGesture(_ recognizer: CandleChartGestureRecognizer, didZoomBy factor: CGFloat, anchorX: CGFloat, panX: CGFloat) {
        viewportState.isScrolling = false
        viewportState.zoom(factor: factor, anchorX: anchorX)
        if panX != 0 {
            _ = viewportState.scrollByPx(panX)
        }
        updatePriceRange(animated: true)
        setNeedsDisplay()
    }
    
    func candleChartGesture(_ recognizer: CandleChartGestureRecognizer, didStartSelectionAt x: CGFloat) {
        selectionFeedback.prepare()
        viewportState.select(at: x)
        setNeedsDisplay()
    }
    
    func candleChartGesture(_ recognizer: CandleChartGestureRecognizer, didMoveSelectionTo x: CGFloat) {
        if viewportState.select(at: x) {
            selectionFeedback.selectionChanged()
        }
        setNeedsDisplay()
    }
    
    func candleChartGestureDidEndSelection(_ recognizer: CandleChartGestureRecognizer) {
        viewportState.clearSelection()
        setNeedsDisplay()
    }
    
}
