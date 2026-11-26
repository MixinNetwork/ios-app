import UIKit

final class CandleChartViewportState {
    
    static let defaultVisibleCandles: CGFloat = 30
    static let minVisibleCandles: CGFloat = 10
    static let maxVisibleCandles: CGFloat = 200
    static let rightPaddingCandles: CGFloat = 0.3
    static let largeScreenCandleSpacing: CGFloat = 10
    
    private(set) var candles: [PerpetualCandleViewModel]
    private(set) var visibleCount: CGFloat
    private(set) var end: CGFloat
    private(set) var followLatest: Bool
    private(set) var plotWidth: CGFloat = 1
    private(set) var maxAxisWidth: CGFloat = 0
    
    var isScrolling: Bool = false
    var selectedIndex: Int?
    var liveWick: PerpetualCandleViewModel.LiveWick?
    
    private var hasInitializedLargeScreenCount = false
    
    var maxVisibleCount: CGFloat {
        max(Self.minVisibleCandles, min(Self.maxVisibleCandles, CGFloat(candles.count)))
    }
    
    var maxEnd: CGFloat {
        candles.isEmpty ? 0 : CGFloat(candles.count) + Self.rightPaddingCandles
    }
    
    var minEnd: CGFloat {
        min(visibleCount, maxEnd)
    }
    
    var step: CGFloat {
        plotWidth / max(visibleCount, Self.minVisibleCandles)
    }
    
    var visibleIndices: ClosedRange<Int>? {
        guard !candles.isEmpty else {
            return nil
        }
        let first = max(0, Int(floor(end - visibleCount)))
        let last = min(candles.count - 1, Int(ceil(end)) - 1)
        guard first <= last else {
            return nil
        }
        return first...last
    }
    
    init(
        candles: [PerpetualCandleViewModel],
        visibleCount: CGFloat,
        followLatest: Bool
    ) {
        self.candles = candles
        self.visibleCount = max(Self.minVisibleCandles, min(Self.maxVisibleCandles, visibleCount))
        self.followLatest = followLatest
        self.end = candles.isEmpty ? 0 : CGFloat(candles.count) + Self.rightPaddingCandles
    }
    
    static func initialLargeScreenVisibleCount(plotWidth: CGFloat, candleCount: Int) -> CGFloat {
        let maxVisible = max(minVisibleCandles, min(maxVisibleCandles, CGFloat(candleCount)))
        let target = max(defaultVisibleCandles, plotWidth / largeScreenCandleSpacing)
        return max(minVisibleCandles, min(maxVisible, target))
    }
    
    func updateLayout(plotWidth: CGFloat, isRegularWidth: Bool) {
        self.plotWidth = max(1, plotWidth)
        applyInitialLargeScreenCountIfNeeded(isRegularWidth: isRegularWidth)
    }
    
    func xOf(_ position: CGFloat) -> CGFloat {
        plotWidth - (end - position) * step
    }
    
    func centerX(forIndex index: Int) -> CGFloat {
        xOf(CGFloat(index) + 0.5)
    }
    
    func indexAt(x: CGFloat) -> Int? {
        guard !candles.isEmpty, plotWidth > 0, step > 0 else {
            return nil
        }
        let raw = Int(floor(end - (plotWidth - x) / step))
        return max(0, min(candles.count - 1, raw))
    }
    
    @discardableResult
    func scrollByPx(_ deltaX: CGFloat) -> Bool {
        guard !candles.isEmpty, step > 0, deltaX != 0, deltaX.isFinite else {
            return false
        }
        let previousEnd = end
        let unclamped = end - deltaX / step
        let clamped = max(minEnd, min(maxEnd, unclamped))
        end = clamped
        followLatest = (end >= maxEnd - 0.5)
        let hitBoundary = unclamped < minEnd || unclamped > maxEnd || abs(clamped - previousEnd) <= 1e-9
        return !hitBoundary
    }
    
    func zoom(factor: CGFloat, anchorX: CGFloat, panX: CGFloat) {
        guard !candles.isEmpty,
              factor > 0,
              factor.isFinite,
              anchorX.isFinite,
              panX.isFinite,
              plotWidth > 0
        else {
            return
        }
        hasInitializedLargeScreenCount = true
        let oldStep = step
        let distanceFromRight = plotWidth - anchorX
        let anchorPosition = end - distanceFromRight / oldStep
        visibleCount = max(Self.minVisibleCandles, min(maxVisibleCount, visibleCount / factor))
        let targetEnd = if followLatest {
            maxEnd - panX / step
        } else {
            anchorPosition + (distanceFromRight - panX) / step
        }
        end = max(minEnd, min(maxEnd, targetEnd))
        if panX != 0 {
            followLatest = end >= maxEnd - 0.5
        }
    }
    
    func updateCandles(_ newCandles: [PerpetualCandleViewModel], isRegularWidth: Bool) {
        let oldCandles = candles
        let selectedTimestamp: Int64? = if let selectedIndex, selectedIndex >= 0, selectedIndex < oldCandles.count {
            oldCandles[selectedIndex].timestamp
        } else {
            nil
        }
        
        candles = newCandles
        
        if let selectedTimestamp {
            selectedIndex = newCandles.firstIndex(where: { $0.timestamp == selectedTimestamp })
        } else {
            selectedIndex = nil
        }
        
        guard !newCandles.isEmpty else {
            end = 0
            followLatest = true
            selectedIndex = nil
            maxAxisWidth = 0
            return
        }
        
        applyInitialLargeScreenCountIfNeeded(isRegularWidth: isRegularWidth)
        
        if followLatest || oldCandles.isEmpty {
            end = maxEnd
        } else {
            let oldLastIndex = oldCandles.count - 1
            let oldLastTimestamp = oldCandles[oldLastIndex].timestamp
            if let newIndex = newCandles.firstIndex(where: { $0.timestamp == oldLastTimestamp }) {
                let shift = CGFloat(newIndex - oldLastIndex)
                end = max(minEnd, min(maxEnd, end + shift))
            } else {
                end = max(minEnd, min(maxEnd, end))
            }
        }
    }
    
    @discardableResult
    func select(at x: CGFloat) -> Bool {
        let newIndex = indexAt(x: x)
        let changed = newIndex != selectedIndex
        selectedIndex = newIndex
        return changed
    }
    
    func clearSelection() {
        selectedIndex = nil
    }
    
    func scrollToLatest() {
        followLatest = true
        end = maxEnd
    }
    
    @discardableResult
    func updateAxisWidth(measuredWidth: CGFloat) -> CGFloat {
        maxAxisWidth = max(maxAxisWidth, measuredWidth)
        return maxAxisWidth
    }
    
    func resetAxisWidth() {
        maxAxisWidth = 0
    }
    
    private func applyInitialLargeScreenCountIfNeeded(isRegularWidth: Bool) {
        guard isRegularWidth,
              !hasInitializedLargeScreenCount,
              plotWidth > 1,
              !candles.isEmpty
        else {
            return
        }
        visibleCount = Self.initialLargeScreenVisibleCount(plotWidth: plotWidth, candleCount: candles.count)
        hasInitializedLargeScreenCount = true
        if followLatest {
            end = maxEnd
        } else {
            end = max(minEnd, min(maxEnd, end))
        }
    }
    
}
