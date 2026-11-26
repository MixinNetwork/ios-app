import UIKit

struct PriceRange: Equatable {
    var min: Double
    var max: Double
}

final class PriceRangeAnimator {
    
    static let animationDuration: CFTimeInterval = 0.22
    
    var onUpdate: (() -> Void)?
    
    private(set) var from: PriceRange?
    private(set) var to: PriceRange?
    private(set) var progress: Double = 1.0
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    
    var isAnimating: Bool {
        displayLink != nil
    }
    
    var current: PriceRange? {
        guard let to else {
            return nil
        }
        guard let from, progress < 1.0 else {
            return to
        }
        let eased = Self.fastOutSlowInEase(progress)
        return PriceRange(
            min: from.min + (to.min - from.min) * eased,
            max: from.max + (to.max - from.max) * eased
        )
    }
    
    deinit {
        stopAnimation()
    }
    
    static func fastOutSlowInEase(_ t: Double) -> Double {
        let clamped = Swift.max(0.0, Swift.min(1.0, t))
        if clamped == 0.0 || clamped == 1.0 {
            return clamped
        }
        // Cubic Bezier control points (0.4, 0.0, 0.2, 1.0)
        let x1 = 0.4
        let x2 = 0.2
        
        func bezierX(_ u: Double) -> Double {
            let inv = 1.0 - u
            return 3.0 * inv * inv * u * x1 + 3.0 * inv * u * u * x2 + u * u * u
        }
        
        func bezierXDerivative(_ u: Double) -> Double {
            let inv = 1.0 - u
            return 3.0 * inv * inv * x1 + 6.0 * inv * u * (x2 - x1) + 3.0 * u * u * (1.0 - x2)
        }
        
        func bezierY(_ u: Double) -> Double {
            // y1 = 0.0, y2 = 1.0
            let inv = 1.0 - u
            return 3.0 * inv * u * u + u * u * u
        }
        
        var u = clamped
        var low = 0.0
        var high = 1.0
        for _ in 0..<12 {
            let x = bezierX(u)
            let err = x - clamped
            if abs(err) < 1e-6 {
                break
            }
            if err < 0 {
                low = u
            } else {
                high = u
            }
            let deriv = bezierXDerivative(u)
            if abs(deriv) > 1e-6 {
                let candidate = u - err / deriv
                if candidate > low && candidate < high {
                    u = candidate
                    continue
                }
            }
            u = (low + high) * 0.5
        }
        return bezierY(u)
    }
    
    static func visiblePriceRange(
        candles: [PerpetualCandleViewModel],
        visibleIndices: ClosedRange<Int>,
        latestPrice: Double?
    ) -> PriceRange? {
        guard !candles.isEmpty else {
            return nil
        }
        let lower = Swift.max(0, visibleIndices.lowerBound)
        let upper = Swift.min(candles.count - 1, visibleIndices.upperBound)
        guard lower <= upper else {
            return nil
        }
        
        var low = Double.greatestFiniteMagnitude
        var high = -Double.greatestFiniteMagnitude
        for index in lower...upper {
            let candle = candles[index]
            low = Swift.min(low, candle.low.doubleValue)
            high = Swift.max(high, candle.high.doubleValue)
        }
        if upper == candles.count - 1, let latestPrice, latestPrice.isFinite {
            low = Swift.min(low, latestPrice)
            high = Swift.max(high, latestPrice)
        }
        guard low.isFinite, high.isFinite else {
            return nil
        }
        let pad: Double = if high == low {
            Swift.max(abs(high) * 0.001, 1e-8)
        } else {
            (high - low) * 0.08
        }
        return PriceRange(min: low - pad, max: high + pad)
    }
    
    static func immediateRange(
        candles: [PerpetualCandleViewModel],
        visibleIndices: ClosedRange<Int>,
        latestPrice: Double?
    ) -> PriceRange? {
        visiblePriceRange(candles: candles, visibleIndices: visibleIndices, latestPrice: latestPrice)
    }
    
    func update(target: PriceRange, hold: Bool, startDisplayLink: Bool = true) {
        guard let currentRange = current, let toRange = to else {
            snap(to: target)
            return
        }
        let next: PriceRange = if hold {
            PriceRange(
                min: Swift.min(currentRange.min, target.min),
                max: Swift.max(currentRange.max, target.max)
            )
        } else {
            target
        }
        if hold && next == currentRange {
            if toRange != currentRange {
                snap(to: currentRange)
            }
            return
        }
        guard next != toRange else {
            return
        }
        from = currentRange
        to = next
        progress = 0.0
        if startDisplayLink {
            beginDisplayLink()
        }
    }
    
    func snap(to target: PriceRange) {
        stopAnimation()
        from = target
        to = target
        progress = 1.0
    }
    
    func reset() {
        stopAnimation()
        from = nil
        to = nil
        progress = 1.0
    }
    
    @discardableResult
    func advance(elapsed: CFTimeInterval) -> Bool {
        guard progress < 1.0, elapsed > 0 else {
            return false
        }
        let delta = elapsed / Self.animationDuration
        progress = Swift.min(1.0, progress + delta)
        if progress >= 1.0 {
            from = to
            stopAnimation()
        }
        return true
    }
    
    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
    }
    
    private func beginDisplayLink() {
        guard displayLink == nil else {
            return
        }
        lastTimestamp = nil
        let proxy = DisplayLinkProxy(target: self)
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    
    fileprivate func handleDisplayLink(_ link: CADisplayLink) {
        let now = link.timestamp
        let elapsed: CFTimeInterval
        if let lastTimestamp {
            elapsed = Swift.max(0, now - lastTimestamp)
        } else {
            elapsed = link.targetTimestamp - link.timestamp
        }
        lastTimestamp = now
        if advance(elapsed: elapsed) {
            onUpdate?()
        }
    }
    
}

private final class DisplayLinkProxy {
    
    weak var target: PriceRangeAnimator?
    
    init(target: PriceRangeAnimator) {
        self.target = target
    }
    
    @objc func step(_ link: CADisplayLink) {
        target?.handleDisplayLink(link)
    }
    
}
