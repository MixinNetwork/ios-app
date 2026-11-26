import XCTest
@testable import Mixin
@testable import MixinServices

final class PerpetualCandleChartTests: XCTestCase {
    
    // MARK: - Helpers
    
    private func makeCandle(
        timestamp: Int64,
        open: String = "100",
        high: String = "110",
        low: String = "90",
        close: String = "105"
    ) -> PerpetualCandleViewModel {
        PerpetualCandleViewModel(
            timestamp: timestamp,
            time: "",
            open: NSDecimalNumber(string: open, locale: Locale.enUSPOSIX),
            high: NSDecimalNumber(string: high, locale: Locale.enUSPOSIX),
            low: NSDecimalNumber(string: low, locale: Locale.enUSPOSIX),
            close: NSDecimalNumber(string: close, locale: Locale.enUSPOSIX)
        )
    }
    
    private func makeCandles(count: Int, startMillis: Int64 = 1_700_000_000_000, stepMillis: Int64 = 60_000) -> [PerpetualCandleViewModel] {
        (0..<count).map { index in
            let ts = startMillis + Int64(index) * stepMillis
            let base = 100 + index
            return makeCandle(
                timestamp: ts,
                open: "\(base)",
                high: "\(base + 5)",
                low: "\(base - 5)",
                close: "\(base + 2)"
            )
        }
    }
    
    // MARK: - CandleChartViewportState
    
    func testViewportCoordinateMappingAndVisibleIndices() {
        let candles = makeCandles(count: 50)
        let state = CandleChartViewportState(candles: candles)
        state.updateLayout(plotWidth: 300, isRegularWidth: false)
        
        XCTAssertEqual(state.visibleCount, 30, accuracy: 0.001)
        XCTAssertEqual(state.maxEnd, 50.3, accuracy: 0.001)
        XCTAssertEqual(state.end, 50.3, accuracy: 0.001)
        XCTAssertEqual(state.step, 10, accuracy: 0.001)
        
        // Position 50.3 maps to plotWidth (300)
        XCTAssertEqual(state.xOf(50.3), 300, accuracy: 0.001)
        // Last candle [49, 50) center at 49.5 -> 300 - (50.3 - 49.5) * 10 = 292
        XCTAssertEqual(state.centerX(forIndex: 49), 292, accuracy: 0.001)
        XCTAssertEqual(state.indexAt(x: 292), 49)
        XCTAssertEqual(state.indexAt(x: -100), 10)
        XCTAssertEqual(state.indexAt(x: -500), 0)
        XCTAssertEqual(state.indexAt(x: 1000), 49)
        XCTAssertEqual(state.visibleIndices, 20...49)
    }
    
    func testViewportScrollHardBoundsAndFollowLatest() {
        let candles = makeCandles(count: 50)
        let state = CandleChartViewportState(candles: candles)
        state.updateLayout(plotWidth: 300, isRegularWidth: false) // step = 10
        
        // Pushing past right edge clamps at maxEnd and returns false
        XCTAssertFalse(state.scrollByPx(-20))
        XCTAssertEqual(state.end, 50.3, accuracy: 0.001)
        XCTAssertTrue(state.followLatest)
        
        // Dragging right (positive deltaX) moves toward history (end decreases)
        XCTAssertTrue(state.scrollByPx(100)) // 100 / 10 = 10 candles left -> end = 40.3
        XCTAssertEqual(state.end, 40.3, accuracy: 0.001)
        XCTAssertFalse(state.followLatest)
        
        // Dragging past minEnd (30) clamps at 30 and returns false
        XCTAssertFalse(state.scrollByPx(500))
        XCTAssertEqual(state.end, 30, accuracy: 0.001)
        XCTAssertFalse(state.followLatest)
        
        // Scrolling back near maxEnd (within 0.5 candles) re-enables followLatest
        XCTAssertTrue(state.scrollByPx(-200)) // end = 50.0 >= 50.3 - 0.5
        XCTAssertEqual(state.end, 50.0, accuracy: 0.001)
        XCTAssertTrue(state.followLatest)
    }
    
    func testViewportZoomBranches() {
        let candles = makeCandles(count: 60)
        let state = CandleChartViewportState(candles: candles)
        state.updateLayout(plotWidth: 300, isRegularWidth: false)
        
        // Branch A: followLatest == true keeps end pinned to maxEnd
        state.zoom(factor: 2.0, anchorX: 150) // 30 / 2 = 15
        XCTAssertEqual(state.visibleCount, 15, accuracy: 0.001)
        XCTAssertEqual(state.end, 60.3, accuracy: 0.001)
        
        // Zooming beyond min/max clamps cleanly
        state.zoom(factor: 10.0, anchorX: 150)
        XCTAssertEqual(state.visibleCount, 10, accuracy: 0.001)
        state.zoom(factor: 0.01, anchorX: 150)
        XCTAssertEqual(state.visibleCount, 60, accuracy: 0.001) // maxVisibleCount = min(200, 60)
        
        // Branch B: followLatest == false preserves logical anchor position under anchorX
        state.zoom(factor: 2.0, anchorX: 150) // visibleCount = 30
        XCTAssertTrue(state.scrollByPx(150)) // move left 15 candles -> end = 45.3, followLatest = false
        XCTAssertFalse(state.followLatest)
        
        let anchorX: CGFloat = 120
        let oldStep = state.step
        let anchorPositionBefore = state.end - (state.plotWidth - anchorX) / oldStep
        state.zoom(factor: 1.5, anchorX: anchorX) // visibleCount = 20
        let newStep = state.step
        let anchorPositionAfter = state.end - (state.plotWidth - anchorX) / newStep
        XCTAssertEqual(anchorPositionAfter, anchorPositionBefore, accuracy: 0.001)
    }
    
    func testViewportUpdateCandlesAnchoringAndSelectionPreservation() {
        let initial = makeCandles(count: 50, startMillis: 1_000_000_000_000, stepMillis: 60_000)
        let state = CandleChartViewportState(candles: initial)
        state.updateLayout(plotWidth: 300, isRegularWidth: false)
        
        // Scroll into history and select candle at timestamp for index 30
        XCTAssertTrue(state.scrollByPx(100)) // end = 40.3, followLatest = false
        let selectedX = state.centerX(forIndex: 30)
        XCTAssertTrue(state.select(at: selectedX))
        XCTAssertEqual(state.selectedIndex, 30)
        let selectedTimestamp = initial[30].timestamp
        let anchoredXBefore = state.centerX(forIndex: 30)
        
        // Prepend 3 older candles and append 1 new candle
        let prepended = makeCandles(count: 3, startMillis: 1_000_000_000_000 - 3 * 60_000, stepMillis: 60_000)
        let appended = [makeCandle(timestamp: 1_000_000_000_000 + 50 * 60_000)]
        let updated = prepended + initial + appended
        
        state.updateCandles(updated)
        XCTAssertEqual(state.selectedIndex, 33)
        XCTAssertEqual(state.candles[33].timestamp, selectedTimestamp)
        // Old last candle shifted by +3, so end shifted by +3 -> visual position unchanged
        XCTAssertEqual(state.end, 43.3, accuracy: 0.001)
        XCTAssertEqual(state.centerX(forIndex: 33), anchoredXBefore, accuracy: 0.001)
        
        // Switching back to followLatest snaps to new maxEnd
        state.scrollToLatest()
        let more = updated + [makeCandle(timestamp: 1_000_000_000_000 + 51 * 60_000)]
        state.updateCandles(more)
        XCTAssertEqual(state.end, CGFloat(more.count) + 0.3, accuracy: 0.001)
    }
    
    func testViewportLargeScreenInitialSpacing() {
        let candles = makeCandles(count: 150)
        let state = CandleChartViewportState(candles: candles)
        state.updateLayout(plotWidth: 900, isRegularWidth: true) // 900 / 10 = 90
        XCTAssertEqual(state.visibleCount, 90, accuracy: 0.001)
        XCTAssertEqual(state.end, 150.3, accuracy: 0.001)
        
        // Narrow regular width still enforces default minimum of 30
        let narrowState = CandleChartViewportState(candles: candles)
        narrowState.updateLayout(plotWidth: 250, isRegularWidth: true)
        XCTAssertEqual(narrowState.visibleCount, 30, accuracy: 0.001)
    }
    
    // MARK: - PriceRangeAnimator
    
    func testVisiblePriceRangePaddingFlatAndLatestPriceInclusion() {
        let candles = [
            makeCandle(timestamp: 1_700_000_000_000, open: "100", high: "110", low: "90", close: "105"),
            makeCandle(timestamp: 1_700_000_060_000, open: "105", high: "120", low: "100", close: "115"),
            makeCandle(timestamp: 1_700_000_120_000, open: "115", high: "118", low: "112", close: "114"),
        ]
        
        // Last candle is NOT visible -> latestPrice (200) must be ignored
        let rangeWithoutLast = PriceRangeAnimator.visiblePriceRange(
            candles: candles,
            visibleIndices: 0...1,
            latestPrice: 200
        )
        // low = 90, high = 120, span = 30, pad = 2.4 -> [87.6, 122.4]
        XCTAssertEqual(rangeWithoutLast?.min ?? 0, 87.6, accuracy: 1e-6)
        XCTAssertEqual(rangeWithoutLast?.max ?? 0, 122.4, accuracy: 1e-6)
        
        // Last candle IS visible -> latestPrice (150) expands high to 150
        let rangeWithLast = PriceRangeAnimator.visiblePriceRange(
            candles: candles,
            visibleIndices: 1...2,
            latestPrice: 150
        )
        // low = 100, high = 150, span = 50, pad = 4 -> [96, 154]
        XCTAssertEqual(rangeWithLast?.min ?? 0, 96.0, accuracy: 1e-6)
        XCTAssertEqual(rangeWithLast?.max ?? 0, 154.0, accuracy: 1e-6)
        
        // Flat candles fallback
        let flat = [makeCandle(timestamp: 1_700_000_000_000, open: "100", high: "100", low: "100", close: "100")]
        let flatRange = PriceRangeAnimator.visiblePriceRange(candles: flat, visibleIndices: 0...0, latestPrice: nil)
        XCTAssertEqual(flatRange?.min ?? 0, 99.9, accuracy: 1e-6)
        XCTAssertEqual(flatRange?.max ?? 0, 100.1, accuracy: 1e-6)
    }
    
    func testPriceRangeAnimatorHoldExpandOnlyAndEasingConvergence() {
        let animator = PriceRangeAnimator()
        let initial = PriceRange(min: 100, max: 200)
        animator.update(target: initial, hold: false, startDisplayLink: false)
        XCTAssertEqual(animator.current, initial)
        
        // While holding (scrolling), narrower target must NOT shrink range
        let narrower = PriceRange(min: 120, max: 180)
        animator.update(target: narrower, hold: true, startDisplayLink: false)
        XCTAssertEqual(animator.current, initial)
        XCTAssertEqual(animator.to, initial)
        
        // While holding, wider target expands range via 220ms animation
        let wider = PriceRange(min: 80, max: 210)
        animator.update(target: wider, hold: true, startDisplayLink: false)
        XCTAssertEqual(animator.to, wider)
        XCTAssertEqual(animator.progress, 0.0, accuracy: 1e-6)
        
        animator.advance(elapsed: 0.11) // half of 220ms
        let mid = animator.current!
        XCTAssertLessThan(mid.min, 100)
        XCTAssertGreaterThan(mid.min, 80)
        // FastOutSlowInEasing at t = 0.5 is > 0.75
        XCTAssertGreaterThan(PriceRangeAnimator.fastOutSlowInEase(0.5), 0.75)
        
        animator.advance(elapsed: 0.11)
        XCTAssertEqual(animator.progress, 1.0, accuracy: 1e-6)
        XCTAssertEqual(animator.current, wider)
        
        // Release hold (hold == false) allows shrinking back toward narrower target
        animator.update(target: narrower, hold: false, startDisplayLink: false)
        animator.advance(elapsed: 0.10)
        let shrinkingMid = animator.current!
        XCTAssertGreaterThan(shrinkingMid.min, 80)
        XCTAssertLessThan(shrinkingMid.max, 210)
        
        // Interrupting active shrink with hold == true freezes at current range (never keeps shrinking)
        animator.update(target: narrower, hold: true, startDisplayLink: false)
        XCTAssertEqual(animator.current, shrinkingMid)
        XCTAssertEqual(animator.to, shrinkingMid)
        XCTAssertEqual(animator.progress, 1.0, accuracy: 1e-6)
    }
    
    func testPriceRangeAnimatorStaticConvergenceAndChartImmediateSnap() {
        let animator = PriceRangeAnimator()
        animator.update(target: PriceRange(min: 10, max: 20), hold: false, startDisplayLink: false)
        animator.update(target: PriceRange(min: 30, max: 40), hold: false, startDisplayLink: false)
        XCTAssertLessThan(animator.progress, 1.0)
        
        let immediate = PriceRange(min: 50, max: 80)
        animator.snap(to: immediate)
        XCTAssertFalse(animator.isAnimating)
        XCTAssertEqual(animator.progress, 1.0, accuracy: 1e-9)
        XCTAssertEqual(animator.current, immediate)
        
        // Static snapshot configure(animated: false) renders synchronously without starting animation
        let chart = CandlestickChartView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let candles = makeCandles(count: 20)
        chart.configure(
            candles: candles,
            timeFrame: .oneHour,
            latestPrice: 120,
            priceFormatMode: .decimal(priceScale: 2),
            animated: false
        )
        chart.snapPriceRangeWithoutAnimation()
        chart.layoutIfNeeded()
        XCTAssertEqual(chart.viewportState.candles.count, 20)
    }
    
    // MARK: - withLivePrice
    
    func testWithLivePriceAllTimeFramesAndClockSkewBoundaries() {
        let baseSec: Int64 = 1_700_000_000
        let baseMillis: Int64 = baseSec * 1000
        
        let expectedPeriods: [(PerpetualTimeFrame, Int64)] = [
            (.oneMinute, 60_000),
            (.fiveMinutes, 300_000),
            (.fifteenMinutes, 900_000),
            (.oneHour, 3_600_000),
            (.fourHours, 14_400_000),
            (.oneDay, 86_400_000),
            (.oneWeek, 604_800_000),
        ]
        XCTAssertEqual(expectedPeriods.count, PerpetualTimeFrame.allCases.count)
        
        for (timeFrame, period) in expectedPeriods {
            // Pass seconds-precision timestamp to also verify sec->ms normalization
            let candle = makeCandle(timestamp: baseSec, open: "100", high: "105", low: "95", close: "102")
            XCTAssertEqual(candle.timestamp, baseMillis)
            
            // Inside period: updates close, expands high
            let midPeriod = baseMillis + period - 1
            let raised = PerpetualCandleViewModel.withLivePrice(
                candles: [candle],
                lastPrice: 112,
                timeFrame: timeFrame,
                nowMillis: midPeriod
            )
            XCTAssertEqual(raised.last?.close, NSDecimalNumber(string: "112"))
            XCTAssertEqual(raised.last?.high, NSDecimalNumber(string: "112"))
            XCTAssertEqual(raised.last?.low, NSDecimalNumber(string: "95"))
            
            // Inside period: updates close, expands low
            let dropped = PerpetualCandleViewModel.withLivePrice(
                candles: [candle],
                lastPrice: 88,
                timeFrame: timeFrame,
                nowMillis: baseMillis
            )
            XCTAssertEqual(dropped.last?.close, NSDecimalNumber(string: "88"))
            XCTAssertEqual(dropped.last?.high, NSDecimalNumber(string: "105"))
            XCTAssertEqual(dropped.last?.low, NSDecimalNumber(string: "88"))
            
            // Cross-period (client clock ahead / period expired): skipped
            let expired = PerpetualCandleViewModel.withLivePrice(
                candles: [candle],
                lastPrice: 130,
                timeFrame: timeFrame,
                nowMillis: baseMillis + period
            )
            XCTAssertEqual(expired, [candle])
            
            // Client clock slow (nowMillis < lastStart): skipped
            let slowClock = PerpetualCandleViewModel.withLivePrice(
                candles: [candle],
                lastPrice: 130,
                timeFrame: timeFrame,
                nowMillis: baseMillis - 1
            )
            XCTAssertEqual(slowClock, [candle])
        }
        
        // Edge guards: empty, nil, zero, negative, NaN
        let sample = [makeCandle(timestamp: baseMillis)]
        XCTAssertEqual(PerpetualCandleViewModel.withLivePrice(candles: [], lastPrice: 100, timeFrame: .oneMinute, nowMillis: baseMillis), [])
        XCTAssertEqual(PerpetualCandleViewModel.withLivePrice(candles: sample, lastPrice: nil, timeFrame: .oneMinute, nowMillis: baseMillis), sample)
        XCTAssertEqual(PerpetualCandleViewModel.withLivePrice(candles: sample, lastPrice: 0, timeFrame: .oneMinute, nowMillis: baseMillis), sample)
        XCTAssertEqual(PerpetualCandleViewModel.withLivePrice(candles: sample, lastPrice: .nan, timeFrame: .oneMinute, nowMillis: baseMillis), sample)
    }
    
    // MARK: - Price Formatting & Monotonic Axis Width
    
    func testPriceDecimalsAndHalfUpFormattingAndPluggableModes() {
        let usLocale = Locale(identifier: "en_US")
        
        // Derived decimals stripping trailing zeros
        let candles = [
            makeCandle(timestamp: 1_700_000_000_000, close: "1234.5000"),
            makeCandle(timestamp: 1_700_000_060_000, close: "1234.1230"),
        ]
        XCTAssertEqual(CandlePriceFormatter.priceDecimals(candles: candles, priceScale: nil), 3)
        XCTAssertEqual(CandlePriceFormatter.priceDecimals(candles: [], priceScale: nil), 2)
        XCTAssertEqual(CandlePriceFormatter.priceDecimals(candles: candles, priceScale: 25), 18)
        XCTAssertEqual(CandlePriceFormatter.priceDecimals(candles: candles, priceScale: -2), 0)
        
        // Plan 6.2: grouping, zero-padding, HALF_UP, no "$"
        let mode = CandlePriceFormatMode.decimal(priceScale: 2)
        XCTAssertEqual(
            CandlePriceFormatter.format(Decimal(string: "1234.5")!, mode: mode, candles: candles, locale: usLocale),
            "1,234.50"
        )
        XCTAssertEqual(
            CandlePriceFormatter.format(Decimal(string: "1.235")!, mode: mode, candles: candles, locale: usLocale),
            "1.24"
        )
        XCTAssertEqual(
            CandlePriceFormatter.format(Decimal(string: "1.234")!, mode: mode, candles: candles, locale: usLocale),
            "1.23"
        )
        XCTAssertEqual(
            CandlePriceFormatter.format(Decimal(string: "-1.235")!, mode: mode, candles: candles, locale: usLocale),
            "-1.24"
        )
        XCTAssertFalse(
            CandlePriceFormatter.format(Decimal(1000), mode: mode, candles: candles, locale: usLocale).contains("$")
        )
        
        // Pluggable currencyStyle switch
        let currencyStyle = PerpetualMarket.userDisplayPriceFormatStyle(scale: 2)
        let currencyText = CandlePriceFormatter.format(
            Decimal(string: "1234.56")!,
            mode: .currencyStyle(currencyStyle),
            candles: candles,
            locale: usLocale
        )
        XCTAssertTrue(currencyText.contains("1,234.56"))
        
        // Pluggable custom closure
        let customText = CandlePriceFormatter.format(
            Decimal(42),
            mode: .custom { val, dec in "\(val)-\(dec)" },
            candles: candles,
            locale: usLocale
        )
        XCTAssertEqual(customText, "42-3")
        
        // Change percentage
        XCTAssertEqual(
            CandlePriceFormatter.formatChangePercentage(open: 100, close: Decimal(string: "101.235")!, locale: usLocale),
            "↑1.24%"
        )
        XCTAssertEqual(
            CandlePriceFormatter.formatChangePercentage(open: 100, close: Decimal(string: "98.765")!, locale: usLocale),
            "↓1.24%"
        )
    }
    
    func testAxisWidthMinimumMonotonicWithinTimeFrameAndResetOnSwitch() {
        let state = CandleChartViewportState()
        let tinyCandles = [makeCandle(timestamp: 1_700_000_000_000, open: "1", high: "2", low: "1", close: "1")]
        let minWidth = CandlePriceFormatter.measureAxisWidth(
            candles: tinyCandles,
            latestPrice: 1,
            mode: .decimal(priceScale: 0)
        )
        XCTAssertEqual(minWidth, 48)
        
        let wideCandles = [makeCandle(timestamp: 1_700_000_000_000, open: "100000", high: "123456.7890", low: "99999", close: "100000")]
        let wideWidth = CandlePriceFormatter.measureAxisWidth(
            candles: wideCandles,
            latestPrice: 123456.7890,
            mode: .decimal(priceScale: 4)
        )
        XCTAssertGreaterThan(wideWidth, 48)
        
        // Monotonic non-decreasing within same timeframe
        XCTAssertEqual(state.updateAxisWidth(measuredWidth: wideWidth), wideWidth)
        XCTAssertEqual(state.updateAxisWidth(measuredWidth: minWidth), wideWidth)
        
        // View-level verification: same timeframe never shrinks, switching timeframe resets
        let chart = CandlestickChartView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        chart.configure(
            candles: wideCandles,
            timeFrame: .oneMinute,
            latestPrice: Decimal(string: "123456.7890"),
            priceFormatMode: .decimal(priceScale: 4),
            animated: false
        )
        chart.layoutIfNeeded()
        let recordedWideAxis = chart.viewportState.maxAxisWidth
        XCTAssertGreaterThan(recordedWideAxis, 48)
        
        // Same timeframe with narrower numbers keeps recordedWideAxis
        chart.configure(
            candles: tinyCandles,
            timeFrame: .oneMinute,
            latestPrice: 1,
            priceFormatMode: .decimal(priceScale: 4),
            animated: false
        )
        XCTAssertEqual(chart.viewportState.maxAxisWidth, recordedWideAxis)
        
        // Switching timeframe resets axisWidth
        chart.configure(
            candles: tinyCandles,
            timeFrame: .oneHour,
            latestPrice: 1,
            priceFormatMode: .decimal(priceScale: 0),
            animated: false
        )
        XCTAssertEqual(chart.viewportState.maxAxisWidth, 48)
        
        // Clearing candles resets axisWidth
        chart.configure(
            candles: wideCandles,
            timeFrame: .oneHour,
            latestPrice: Decimal(string: "123456.7890"),
            priceFormatMode: .decimal(priceScale: 4),
            animated: false
        )
        XCTAssertGreaterThan(chart.viewportState.maxAxisWidth, 48)
        chart.configure(
            candles: [],
            timeFrame: .oneHour,
            latestPrice: nil,
            priceFormatMode: .decimal(priceScale: 4),
            animated: false
        )
        XCTAssertEqual(chart.viewportState.maxAxisWidth, 0)
    }
    
    func testChartDrawSixLayersAndSelectionSmoke() {
        let size = CGSize(width: 340, height: 220)
        let chart = CandlestickChartView(frame: CGRect(origin: .zero, size: size))
        var candles = makeCandles(count: 40)
        // Include a flat doji candle
        candles[38] = makeCandle(
            timestamp: candles[38].timestamp,
            open: "120",
            high: "120",
            low: "120",
            close: "120"
        )
        
        for timeFrame in PerpetualTimeFrame.allCases {
            chart.configure(
                candles: candles,
                timeFrame: timeFrame,
                latestPrice: 141,
                priceFormatMode: .decimal(priceScale: 2),
                animated: false
            )
            chart.labels = CandleChartLabels(open: "Open", close: "Close", high: "High", low: "Low", date: "Date")
            chart.layoutIfNeeded()
            
            // Test selection on right half (card avoids to left) and left half (card avoids to right)
            chart.viewportState.selectedIndex = 38
            let renderer = UIGraphicsImageRenderer(size: size)
            let rightSelectionImage = renderer.image { _ in
                chart.draw(CGRect(origin: .zero, size: size))
            }
            XCTAssertEqual(rightSelectionImage.size, size)
            
            chart.viewportState.selectedIndex = 12
            let leftSelectionImage = renderer.image { _ in
                chart.draw(CGRect(origin: .zero, size: size))
            }
            XCTAssertEqual(leftSelectionImage.size, size)
        }
    }
    
    func testCompact193ptLayoutBoundsAntiCollisionAndDetailCardFit() throws {
        // Matches PerpetualMarketPriceCell.xib chart height (193pt) -> plotHeight = 161pt
        let size = CGSize(width: 303, height: 193)
        let chart = CandlestickChartView(frame: CGRect(origin: .zero, size: size))
        let candles = makeCandles(count: 40)
        
        // Latest price near top grid line to verify anti-collision & top clamp
        let topLatest = Decimal(string: candles.last!.high.stringValue)!
        chart.configure(
            candles: candles,
            timeFrame: .oneMinute,
            latestPrice: topLatest,
            priceFormatMode: .decimal(priceScale: 2),
            animated: false
        )
        chart.viewportState.selectedIndex = 35
        chart.layoutIfNeeded()
        
        let metrics = try XCTUnwrap(chart.computeRenderMetrics())
        XCTAssertEqual(metrics.plotTop, 8, accuracy: 0.001)
        XCTAssertEqual(metrics.plotBottom, 169, accuracy: 0.001)
        XCTAssertEqual(metrics.plotHeight, 161, accuracy: 0.001)
        
        // Latest capsule stays completely inside 193pt height
        let tagRect = try XCTUnwrap(metrics.latestTagRect)
        XCTAssertGreaterThanOrEqual(tagRect.minY, 0)
        XCTAssertLessThanOrEqual(tagRect.maxY, size.height)
        
        // All visible Y-axis labels stay within [0, 193] and do not collide with latest capsule
        for labelFrame in metrics.gridLabelFrames {
            XCTAssertGreaterThanOrEqual(labelFrame.minY, 0)
            XCTAssertLessThanOrEqual(labelFrame.maxY, size.height)
            XCTAssertFalse(labelFrame.intersects(tagRect))
        }
        
        // Bottom time labels sit below plotBottom (169), inside [169, 193], and do not overlap each other
        XCTAssertGreaterThanOrEqual(metrics.startTimeFrame.minY, metrics.plotBottom)
        XCTAssertLessThanOrEqual(metrics.startTimeFrame.maxY, size.height)
        if let endTimeFrame = metrics.endTimeFrame {
            XCTAssertGreaterThanOrEqual(endTimeFrame.minY, metrics.plotBottom)
            XCTAssertLessThanOrEqual(endTimeFrame.maxY, size.height)
            XCTAssertGreaterThanOrEqual(endTimeFrame.minX, metrics.startTimeFrame.maxX + 8 - 0.001)
        }
        
        // 5-row detail card fits strictly inside [plotTop, plotBottom] (never overlaps bottom time area)
        let cardRect = try XCTUnwrap(metrics.detailCardRect)
        XCTAssertGreaterThanOrEqual(cardRect.minY, metrics.plotTop)
        XCTAssertLessThanOrEqual(cardRect.maxY, metrics.plotBottom)
        XCTAssertGreaterThanOrEqual(cardRect.minX, 0)
        XCTAssertLessThanOrEqual(cardRect.maxX, size.width)
        XCTAssertFalse(cardRect.intersects(metrics.startTimeFrame))
    }
    
}
