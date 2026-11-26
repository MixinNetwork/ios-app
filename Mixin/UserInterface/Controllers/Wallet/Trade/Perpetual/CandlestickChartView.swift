import UIKit
import MixinServices

final class CandlestickChartView: UIView {
    
    struct RenderMetrics {
        let plotTop: CGFloat
        let plotBottom: CGFloat
        let plotHeight: CGFloat
        let axisWidth: CGFloat
        let plotWidth: CGFloat
        let axisTextX: CGFloat
        let gridLabelFrames: [CGRect]
        let latestLineY: CGFloat?
        let latestTagRect: CGRect?
        let startTimeFrame: CGRect
        let endTimeFrame: CGRect?
        let detailCardRect: CGRect?
    }
    
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
    
    private let rangeAnimator = PriceRangeAnimator()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private lazy var chartGestureRecognizer = CandleChartGestureRecognizer(target: nil, action: nil)
    
    private var lastLayoutSize: CGSize = .zero
    private var isApplyingConfiguration = false
    
    override init(frame: CGRect) {
        self.viewportState = CandleChartViewportState(
            candles: [],
            visibleCount: CandleChartViewportState.defaultVisibleCandles,
            followLatest: true
        )
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        self.viewportState = CandleChartViewportState(
            candles: [],
            visibleCount: CandleChartViewportState.defaultVisibleCandles,
            followLatest: true
        )
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
        priceFormatMode: CandlePriceFormatMode?,
        viewportState: CandleChartViewportState?,
        animated: Bool
    ) {
        let didSwapState = viewportState != nil && viewportState !== self.viewportState
        if didSwapState || timeFrame != self.timeFrame {
            // Stops the display link from driving the next viewport and resets isScrolling on the current one
            chartGestureRecognizer.stopFling()
        }
        isApplyingConfiguration = true
        if let viewportState, viewportState !== self.viewportState {
            self.viewportState = viewportState
        } else if timeFrame != self.timeFrame {
            self.viewportState.resetAxisWidth()
        }
        self.timeFrame = timeFrame
        if let priceFormatMode {
            let modeChanged = switch (self.priceFormatMode, priceFormatMode) {
            case let (.decimal(l), .decimal(r)):
                l != r
            case let (.currencyStyle(l), .currencyStyle(r)):
                l != r
            default:
                true
            }
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
    
    func snapPriceRangeWithoutAnimation() {
        syncLayoutAndRange(animated: false)
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
        
        guard let metrics = prepareRenderMetrics() else {
            return
        }
        
        if rangeAnimator.current == nil {
            rangeAnimator.snap(to: metrics.range)
        }
        
        let textAssistColor = (R.color.text_tertiary() ?? .secondaryLabel).resolvedColor(with: traitCollection)
        let risingColor = MarketColor.rising.uiColor.resolvedColor(with: traitCollection)
        let fallingColor = MarketColor.falling.uiColor.resolvedColor(with: traitCollection)
        
        let gridStrokeColor = textAssistColor.withAlphaComponent(0.3).cgColor
        let axisAttributes: [NSAttributedString.Key: Any] = [
            .font: Config.axisFont,
            .foregroundColor: textAssistColor,
        ]
        
        // Layer 2: 4 horizontal dashed grid lines & anti-collision Y-axis labels
        for item in metrics.gridItems {
            context.saveGState()
            context.setStrokeColor(gridStrokeColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: Config.gridDashLengths)
            context.move(to: CGPoint(x: 0, y: item.lineY))
            context.addLine(to: CGPoint(x: metrics.plotWidth, y: item.lineY))
            context.strokePath()
            context.restoreGState()
            
            if let labelFrame = item.labelFrame {
                (item.priceText as NSString).draw(
                    at: labelFrame.origin,
                    withAttributes: axisAttributes
                )
            }
        }
        
        // Layer 3: Rounded candles using standard circular-arc CGPath
        context.saveGState()
        context.clip(to: CGRect(x: 0, y: metrics.plotTop, width: metrics.plotWidth, height: metrics.plotHeight))
        
        let step = viewportState.step
        let bodyWidth = step * 0.7
        let wickWidth = min(max(bodyWidth * 0.3, 1.5), 3.0)
        
        for index in metrics.visibleIndices {
            let candle = candles[index]
            let isBull = candle.close.compare(candle.open) != .orderedAscending
            let fillColor = (isBull ? risingColor : fallingColor).cgColor
            context.setFillColor(fillColor)
            
            let centerX = viewportState.centerX(forIndex: index)
            let highY = yCoordinate(for: candle.high.doubleValue, range: metrics.range, plotBottom: metrics.plotBottom, plotHeight: metrics.plotHeight)
            let lowY = yCoordinate(for: candle.low.doubleValue, range: metrics.range, plotBottom: metrics.plotBottom, plotHeight: metrics.plotHeight)
            let openY = yCoordinate(for: candle.open.doubleValue, range: metrics.range, plotBottom: metrics.plotBottom, plotHeight: metrics.plotHeight)
            let closeY = yCoordinate(for: candle.close.doubleValue, range: metrics.range, plotBottom: metrics.plotBottom, plotHeight: metrics.plotHeight)
            
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
        if let latest = metrics.latestItem {
            let latestColor = latest.isBull ? risingColor : fallingColor
            
            context.saveGState()
            context.setStrokeColor(latestColor.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: 0, y: latest.lineY))
            context.addLine(to: CGPoint(x: metrics.plotWidth, y: latest.lineY))
            context.strokePath()
            
            let latestAttributes: [NSAttributedString.Key: Any] = [
                .font: Config.axisFont,
                .foregroundColor: latestColor,
            ]
            let tagRadius = safeCornerRadius(latest.tagRect.height / 2, for: latest.tagRect)
            let tagPath = CGPath(roundedRect: latest.tagRect, cornerWidth: tagRadius, cornerHeight: tagRadius, transform: nil)
            context.setFillColor(latestColor.withAlphaComponent(0.12).cgColor)
            context.addPath(tagPath)
            context.fillPath()
            
            (latest.priceText as NSString).draw(
                at: latest.textOrigin,
                withAttributes: latestAttributes
            )
            context.restoreGState()
        }
        
        // Layer 5: Bottom first/last timestamps with overlap guard
        (metrics.startTimeText as NSString).draw(at: metrics.startTimeFrame.origin, withAttributes: axisAttributes)
        if let endTimeText = metrics.endTimeText, let endTimeFrame = metrics.endTimeFrame {
            (endTimeText as NSString).draw(at: endTimeFrame.origin, withAttributes: axisAttributes)
        }
        
        // Layer 6: Crosshair (locked to closeY, no dot) & 5-row detail card
        if let selection = metrics.selection {
            drawSelection(
                in: context,
                selection: selection,
                plotTop: metrics.plotTop,
                plotBottom: metrics.plotBottom,
                plotWidth: metrics.plotWidth,
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
            font: Config.axisFont,
            locale: .current
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
            rangeAnimator.update(
                target: target,
                hold: viewportState.isScrolling,
                startDisplayLink: true
            )
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
            candles: viewportState.candles,
            locale: .current
        )
    }
    
    private func formatAxisTime(_ timestampMillis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestampMillis) / 1000)
        let formatter: DateFormatter = timeFrame.usesDateOnlyFormat
            ? Self.dailyAxisDateFormatter
            : Self.intradayAxisDateFormatter
        return formatter.string(from: date)
    }
    
    private struct PreparedGridItem {
        let lineY: CGFloat
        let priceText: String
        let labelFrame: CGRect?
    }
    
    private struct PreparedLatestItem {
        let lineY: CGFloat
        let priceText: String
        let isBull: Bool
        let tagRect: CGRect
        let textOrigin: CGPoint
    }
    
    private struct PreparedSelectionRow {
        let title: String
        let value: String
        let suffix: String?
        let titleSize: CGSize
        let valueSize: CGSize
        let rowHeight: CGFloat
    }
    
    private struct PreparedSelection {
        let centerX: CGFloat
        let closeY: CGFloat
        let isRising: Bool
        let cardRect: CGRect
        let maxTitleWidth: CGFloat
        let rows: [PreparedSelectionRow]
    }
    
    private struct PreparedMetrics {
        let plotTop: CGFloat
        let plotBottom: CGFloat
        let plotHeight: CGFloat
        let axisWidth: CGFloat
        let plotWidth: CGFloat
        let axisTextX: CGFloat
        let visibleIndices: ClosedRange<Int>
        let range: PriceRange
        let gridItems: [PreparedGridItem]
        let latestItem: PreparedLatestItem?
        let startTimeText: String
        let startTimeFrame: CGRect
        let endTimeText: String?
        let endTimeFrame: CGRect?
        let selection: PreparedSelection?
    }
    
    private func drawSelection(
        in context: CGContext,
        selection: PreparedSelection,
        plotTop: CGFloat,
        plotBottom: CGFloat,
        plotWidth: CGFloat,
        textAssistColor: UIColor,
        risingColor: UIColor,
        fallingColor: UIColor
    ) {
        // Crosshair solid lines (locked to closeY, no dot)
        context.saveGState()
        context.setStrokeColor(textAssistColor.withAlphaComponent(0.7).cgColor)
        context.setLineWidth(1)
        if selection.centerX >= 0 && selection.centerX <= plotWidth {
            context.move(to: CGPoint(x: selection.centerX, y: plotTop))
            context.addLine(to: CGPoint(x: selection.centerX, y: plotBottom))
        }
        context.move(to: CGPoint(x: 0, y: selection.closeY))
        context.addLine(to: CGPoint(x: plotWidth, y: selection.closeY))
        context.strokePath()
        context.restoreGState()
        
        // 5-row detail card
        let changeColor = selection.isRising ? risingColor : fallingColor
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
        
        let cardRect = selection.cardRect
        let cardRadius = safeCornerRadius(Config.cardCornerRadius, for: cardRect)
        let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)
        
        context.saveGState()
        context.setFillColor(Config.cardBackgroundColor.cgColor)
        context.addPath(cardPath)
        context.fillPath()
        
        let titleRightEdge = cardRect.minX + Config.cardPadH + selection.maxTitleWidth
        let valueLeftEdge = titleRightEdge + Config.cardColumnGap
        var currentY = cardRect.minY + Config.cardPadV
        
        for row in selection.rows {
            (row.title as NSString).draw(
                at: CGPoint(x: titleRightEdge - row.titleSize.width, y: currentY),
                withAttributes: titleAttributes
            )
            (row.value as NSString).draw(
                at: CGPoint(x: valueLeftEdge, y: currentY),
                withAttributes: valueAttributes
            )
            if let suffix = row.suffix {
                (suffix as NSString).draw(
                    at: CGPoint(x: valueLeftEdge + row.valueSize.width + Config.cardChangeGap, y: currentY),
                    withAttributes: changeAttributes
                )
            }
            currentY += row.rowHeight + Config.cardRowSpacing
        }
        context.restoreGState()
    }
    
    func computeRenderMetrics() -> RenderMetrics? {
        guard let prepared = prepareRenderMetrics() else {
            return nil
        }
        return RenderMetrics(
            plotTop: prepared.plotTop,
            plotBottom: prepared.plotBottom,
            plotHeight: prepared.plotHeight,
            axisWidth: prepared.axisWidth,
            plotWidth: prepared.plotWidth,
            axisTextX: prepared.axisTextX,
            gridLabelFrames: prepared.gridItems.compactMap(\.labelFrame),
            latestLineY: prepared.latestItem?.lineY,
            latestTagRect: prepared.latestItem?.tagRect,
            startTimeFrame: prepared.startTimeFrame,
            endTimeFrame: prepared.endTimeFrame,
            detailCardRect: prepared.selection?.cardRect
        )
    }
    
    private func prepareRenderMetrics() -> PreparedMetrics? {
        let candles = viewportState.candles
        guard !candles.isEmpty,
              bounds.width > 0,
              bounds.height > Config.plotTop + Config.plotBottomInset
        else {
            return nil
        }
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
            return nil
        }
        let range: PriceRange
        if let currentRange = rangeAnimator.current {
            range = currentRange
        } else if let immediate = PriceRangeAnimator.visiblePriceRange(
            candles: candles,
            visibleIndices: visibleIndices,
            latestPrice: latestPriceDouble
        ) {
            range = immediate
        } else {
            return nil
        }
        
        let axisAttributes: [NSAttributedString.Key: Any] = [.font: Config.axisFont]
        let sampleHeight = ("0" as NSString).size(withAttributes: axisAttributes).height
        let latestTagHeight = sampleHeight + 4
        let latestY = latestPriceDouble.map { yCoordinate(for: $0, range: range, plotBottom: plotBottom, plotHeight: plotHeight) }
        let showLatest = latestY.map { $0 >= plotTop && $0 <= plotBottom } ?? false
        
        var gridItems: [PreparedGridItem] = []
        gridItems.reserveCapacity(Config.gridLineCount)
        let priceSpan = range.max - range.min
        for i in 0..<Config.gridLineCount {
            let fraction = CGFloat(i) / CGFloat(Config.gridLineCount - 1)
            let lineY = plotTop + plotHeight * fraction
            let price = range.max - priceSpan * Double(fraction)
            let priceText = formatPrice(Decimal(price))
            let labelSize = (priceText as NSString).size(withAttributes: axisAttributes)
            var labelCenterY = lineY
            if showLatest, let latestY {
                let minGap = (latestTagHeight + labelSize.height) / 2 + 2
                if abs(labelCenterY - latestY) < minGap {
                    labelCenterY = (labelCenterY < latestY) ? (latestY - minGap) : (latestY + minGap)
                }
            }
            let labelTop = labelCenterY - labelSize.height / 2
            let labelBottom = labelCenterY + labelSize.height / 2
            let labelFrame: CGRect? = if labelTop >= 0 && labelBottom <= bounds.height {
                CGRect(x: axisTextX, y: labelTop, width: labelSize.width, height: labelSize.height)
            } else {
                nil
            }
            gridItems.append(PreparedGridItem(lineY: lineY, priceText: priceText, labelFrame: labelFrame))
        }
        
        var latestItem: PreparedLatestItem?
        if showLatest, let latestY, let latestDecimal = latestPrice, let lastCandle = candles.last {
            let priceText = formatPrice(latestDecimal)
            let textSize = (priceText as NSString).size(withAttributes: axisAttributes)
            let padH: CGFloat = 6
            let padV: CGFloat = 2
            let tagHeight = textSize.height + padV * 2
            let tagWidth = textSize.width + padH * 2
            let tagY = max(0, min(bounds.height - tagHeight, latestY - tagHeight / 2))
            let tagRect = CGRect(x: axisTextX - padH, y: tagY, width: tagWidth, height: tagHeight)
            latestItem = PreparedLatestItem(
                lineY: latestY,
                priceText: priceText,
                isBull: latestDecimal >= lastCandle.open.decimalValue,
                tagRect: tagRect,
                textOrigin: CGPoint(x: axisTextX, y: tagY + padV)
            )
        }
        
        let timeY = plotBottom + Config.timeBottomOffset
        let firstTimeIndex = min(
            max(visibleIndices.lowerBound, Int(ceil(viewportState.end - viewportState.visibleCount))),
            visibleIndices.upperBound
        )
        let lastTimeIndex = visibleIndices.upperBound
        let startTimeText = formatAxisTime(candles[firstTimeIndex].timestamp)
        let startSize = (startTimeText as NSString).size(withAttributes: axisAttributes)
        let startTimeFrame = CGRect(origin: CGPoint(x: 0, y: timeY), size: startSize)
        var endTimeText: String?
        var endTimeFrame: CGRect?
        if firstTimeIndex < lastTimeIndex {
            let text = formatAxisTime(candles[lastTimeIndex].timestamp)
            let endSize = (text as NSString).size(withAttributes: axisAttributes)
            let endX = max(startSize.width + Config.timeMinGap, plotWidth - endSize.width)
            endTimeText = text
            endTimeFrame = CGRect(origin: CGPoint(x: endX, y: timeY), size: endSize)
        }
        
        var selection: PreparedSelection?
        if let selectedIndex = viewportState.selectedIndex,
           selectedIndex >= 0,
           selectedIndex < candles.count
        {
            let selected = candles[selectedIndex]
            let openDecimal = selected.open.decimalValue
            let closeDecimal = selected.close.decimalValue
            let isRising = closeDecimal >= openDecimal
            let changeText = CandlePriceFormatter.formatChangePercentage(
                open: openDecimal,
                close: closeDecimal,
                locale: .current
            )
            let detailDateFormatter: DateFormatter = timeFrame.usesDateOnlyFormat
                ? Self.dailyDetailDateFormatter
                : Self.intradayDetailDateFormatter
            let detailDate = Date(timeIntervalSince1970: TimeInterval(selected.timestamp) / 1000)
            let rawRows: [(String, String, String?)] = [
                (labels.open, formatPrice(openDecimal), nil),
                (labels.close, formatPrice(closeDecimal), changeText),
                (labels.high, formatPrice(selected.high.decimalValue), nil),
                (labels.low, formatPrice(selected.low.decimalValue), nil),
                (labels.date, detailDateFormatter.string(from: detailDate), nil),
            ]
            var rows: [PreparedSelectionRow] = []
            rows.reserveCapacity(rawRows.count)
            var maxTitleWidth: CGFloat = 0
            var maxValueWidth: CGFloat = 0
            var totalRowHeight: CGFloat = 0
            for raw in rawRows {
                let titleSize = (raw.0 as NSString).size(withAttributes: axisAttributes)
                let valueSize = (raw.1 as NSString).size(withAttributes: axisAttributes)
                var width = valueSize.width
                var height = max(titleSize.height, valueSize.height)
                if let suffix = raw.2 {
                    let suffixSize = (suffix as NSString).size(withAttributes: axisAttributes)
                    width += Config.cardChangeGap + suffixSize.width
                    height = max(height, suffixSize.height)
                }
                maxTitleWidth = max(maxTitleWidth, titleSize.width)
                maxValueWidth = max(maxValueWidth, width)
                totalRowHeight += height
                rows.append(PreparedSelectionRow(
                    title: raw.0,
                    value: raw.1,
                    suffix: raw.2,
                    titleSize: titleSize,
                    valueSize: valueSize,
                    rowHeight: height
                ))
            }
            let cardWidth = Config.cardPadH * 2 + maxTitleWidth + Config.cardColumnGap + maxValueWidth
            let cardHeight = Config.cardPadV * 2 + totalRowHeight + Config.cardRowSpacing * CGFloat(max(0, rows.count - 1))
            let cardY = max(0, min(plotTop, plotBottom - cardHeight))
            let centerX = viewportState.centerX(forIndex: selectedIndex)
            let leftX = centerX - Config.cardCrosshairGap - cardWidth
            let rightX = centerX + Config.cardCrosshairGap
            let fitsLeft = leftX >= 0
            let fitsRight = rightX + cardWidth <= bounds.width
            let preferLeft = centerX > plotWidth / 2
            let cardX: CGFloat = if preferLeft && fitsLeft {
                leftX
            } else if !preferLeft && fitsRight {
                rightX
            } else if fitsLeft {
                leftX
            } else if fitsRight {
                rightX
            } else {
                preferLeft ? 0 : max(0, bounds.width - cardWidth)
            }
            let rawCloseY = yCoordinate(
                for: selected.close.doubleValue,
                range: range,
                plotBottom: plotBottom,
                plotHeight: plotHeight
            )
            let closeY = max(plotTop, min(plotBottom, rawCloseY))
            selection = PreparedSelection(
                centerX: centerX,
                closeY: closeY,
                isRising: isRising,
                cardRect: CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight),
                maxTitleWidth: maxTitleWidth,
                rows: rows
            )
        }
        
        return PreparedMetrics(
            plotTop: plotTop,
            plotBottom: plotBottom,
            plotHeight: plotHeight,
            axisWidth: axisWidth,
            plotWidth: plotWidth,
            axisTextX: axisTextX,
            visibleIndices: visibleIndices,
            range: range,
            gridItems: gridItems,
            latestItem: latestItem,
            startTimeText: startTimeText,
            startTimeFrame: startTimeFrame,
            endTimeText: endTimeText,
            endTimeFrame: endTimeFrame,
            selection: selection
        )
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
