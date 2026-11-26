import UIKit

protocol CandleChartGestureRecognizerDelegate: AnyObject {
    func candleChartGestureDidStartInteraction(_ recognizer: CandleChartGestureRecognizer)
    func candleChartGesture(_ recognizer: CandleChartGestureRecognizer, didChangeScrolling isScrolling: Bool)
    func candleChartGesture(_ recognizer: CandleChartGestureRecognizer, didScrollBy deltaX: CGFloat) -> Bool
    func candleChartGesture(_ recognizer: CandleChartGestureRecognizer, didZoomBy factor: CGFloat, anchorX: CGFloat, panX: CGFloat)
    func candleChartGesture(_ recognizer: CandleChartGestureRecognizer, didStartSelectionAt x: CGFloat)
    func candleChartGesture(_ recognizer: CandleChartGestureRecognizer, didMoveSelectionTo x: CGFloat)
    func candleChartGestureDidEndSelection(_ recognizer: CandleChartGestureRecognizer)
}

final class CandleChartGestureRecognizer: UIGestureRecognizer {
    
    private enum Mode {
        case pending
        case drag
        case pinch
        case select
    }
    
    private struct VelocitySample {
        let timestamp: TimeInterval
        let x: CGFloat
    }
    
    weak var chartDelegate: CandleChartGestureRecognizerDelegate?
    
    private let touchSlop: CGFloat = 8
    private let longPressDuration: TimeInterval = 0.3
    private let minFlingVelocity: CGFloat = 60
    private let stopFlingVelocity: CGFloat = 15
    private let flingDecelerationRate: CGFloat = 4.5
    private let velocitySampleWindow: TimeInterval = 0.1
    
    private var mode: Mode = .pending
    private var activeTouches: [UITouch] = []
    private var previousLocations: [ObjectIdentifier: CGPoint] = [:]
    private var initialLocation: CGPoint = .zero
    private var velocitySamples: [VelocitySample] = []
    
    private var longPressTimer: Timer?
    private var flingDisplayLink: CADisplayLink?
    private var flingVelocityX: CGFloat = 0
    private var lastFlingTimestamp: CFTimeInterval?
    
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delegate = self
        cancelsTouchesInView = true
    }
    
    deinit {
        cancelLongPressTimer()
        stopFling(notifyScrollingEnded: false)
    }
    
    func stopFling() {
        stopFling(notifyScrollingEnded: true)
    }
    
    override func reset() {
        super.reset()
        cancelLongPressTimer()
        mode = .pending
        activeTouches.removeAll()
        previousLocations.removeAll()
        velocitySamples.removeAll()
        initialLocation = .zero
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let view else {
            return
        }
        
        if activeTouches.isEmpty {
            // A tap or vertical swipe never reaches .drag, so the fling must end scrolling here
            stopFling(notifyScrollingEnded: true)
            chartDelegate?.candleChartGestureDidStartInteraction(self)
        }
        
        for touch in touches where !activeTouches.contains(touch) {
            activeTouches.append(touch)
            previousLocations[ObjectIdentifier(touch)] = touch.location(in: view)
        }
        
        if activeTouches.count == 1, mode == .pending {
            let point = activeTouches[0].location(in: view)
            initialLocation = point
            velocitySamples = [VelocitySample(timestamp: activeTouches[0].timestamp, x: point.x)]
            heavyFeedback.prepare()
            cancelLongPressTimer()
            let timer = Timer(timeInterval: longPressDuration, repeats: false) { [weak self] _ in
                guard let self else {
                    return
                }
                longPressTimer = nil
                guard mode == .pending,
                      activeTouches.count == 1,
                      state == .possible,
                      let view = self.view,
                      let touch = activeTouches.first
                else {
                    return
                }
                mode = .select
                state = .began
                heavyFeedback.impactOccurred()
                let x = touch.location(in: view).x
                chartDelegate?.candleChartGesture(self, didStartSelectionAt: x)
            }
            RunLoop.main.add(timer, forMode: .common)
            longPressTimer = timer
        } else if activeTouches.count > 1 {
            cancelLongPressTimer()
            if mode == .select {
                chartDelegate?.candleChartGestureDidEndSelection(self)
            }
            if mode == .drag {
                chartDelegate?.candleChartGesture(self, didChangeScrolling: false)
            }
            mode = .pinch
            velocitySamples.removeAll()
            // Sync all active touches to prevent centroid jump when adding a second finger
            for touch in activeTouches {
                previousLocations[ObjectIdentifier(touch)] = touch.location(in: view)
            }
            if state == .possible {
                state = .began
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let view, !activeTouches.isEmpty else {
            return
        }
        
        switch mode {
        case .pending:
            guard let touch = activeTouches.first else {
                return
            }
            let current = touch.location(in: view)
            let dx = current.x - initialLocation.x
            let dy = current.y - initialLocation.y
            let distance = hypot(dx, dy)
            if distance >= touchSlop {
                cancelLongPressTimer()
                if abs(dx) < abs(dy) {
                    state = .failed
                    return
                }
                mode = .drag
                chartDelegate?.candleChartGesture(self, didChangeScrolling: true)
                state = .began
                let prevX = previousLocations[ObjectIdentifier(touch)]?.x ?? initialLocation.x
                let frameDeltaX = current.x - prevX
                recordVelocitySample(timestamp: touch.timestamp, x: current.x)
                if frameDeltaX != 0 {
                    _ = chartDelegate?.candleChartGesture(self, didScrollBy: frameDeltaX)
                }
            }
            
        case .drag:
            guard let touch = activeTouches.first else {
                return
            }
            let current = touch.location(in: view)
            let prev = previousLocations[ObjectIdentifier(touch)] ?? current
            let deltaX = current.x - prev.x
            recordVelocitySample(timestamp: touch.timestamp, x: current.x)
            if deltaX != 0 {
                _ = chartDelegate?.candleChartGesture(self, didScrollBy: deltaX)
            }
            if state == .began || state == .changed {
                state = .changed
            }
            
        case .pinch:
            let prevPoints = activeTouches.map { previousLocations[ObjectIdentifier($0)] ?? $0.location(in: view) }
            let currPoints = activeTouches.map { $0.location(in: view) }
            let prevCentroid = centroid(of: prevPoints)
            let currCentroid = centroid(of: currPoints)
            let panX = currCentroid.x - prevCentroid.x
            var zoomFactor: CGFloat = 1.0
            if activeTouches.count >= 2 {
                let prevSpan = averageSpan(of: prevPoints, centroid: prevCentroid)
                let currSpan = averageSpan(of: currPoints, centroid: currCentroid)
                if prevSpan > 1 && currSpan > 1 {
                    zoomFactor = currSpan / prevSpan
                }
            }
            // Zoom around the previous centroid, then pan, so the candle under the fingers follows them
            chartDelegate?.candleChartGesture(
                self,
                didZoomBy: zoomFactor,
                anchorX: prevCentroid.x,
                panX: panX
            )
            if state == .began || state == .changed {
                state = .changed
            }
            
        case .select:
            if let touch = activeTouches.first {
                let x = touch.location(in: view).x
                chartDelegate?.candleChartGesture(self, didMoveSelectionTo: x)
                if state == .began || state == .changed {
                    state = .changed
                }
            }
        }
        
        for touch in activeTouches {
            previousLocations[ObjectIdentifier(touch)] = touch.location(in: view)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        handleTouchesFinished(touches, cancelled: false)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        handleTouchesFinished(touches, cancelled: true)
    }
    
    private func handleTouchesFinished(_ touches: Set<UITouch>, cancelled: Bool) {
        for touch in touches {
            activeTouches.removeAll { $0 === touch }
            previousLocations.removeValue(forKey: ObjectIdentifier(touch))
        }
        
        guard activeTouches.isEmpty else {
            // Remaining finger stays in Pinch without centroid jump or fling
            if let view {
                for touch in activeTouches {
                    previousLocations[ObjectIdentifier(touch)] = touch.location(in: view)
                }
            }
            return
        }
        
        cancelLongPressTimer()
        switch mode {
        case .pending:
            state = .failed
        case .drag:
            let releaseTimestamp = touches.map(\.timestamp).max() ?? 0
            let velocityX = cancelled ? 0 : computeHorizontalVelocity(releaseTimestamp: releaseTimestamp)
            if abs(velocityX) >= minFlingVelocity {
                stopFling(notifyScrollingEnded: false)
                flingVelocityX = velocityX
                lastFlingTimestamp = nil
                let proxy = FlingDisplayLinkProxy(target: self)
                let link = CADisplayLink(target: proxy, selector: #selector(FlingDisplayLinkProxy.step(_:)))
                link.add(to: .main, forMode: .common)
                flingDisplayLink = link
            } else {
                chartDelegate?.candleChartGesture(self, didChangeScrolling: false)
            }
            state = cancelled ? .cancelled : .ended
        case .pinch:
            // Last finger lifting from pinch never triggers fling
            state = cancelled ? .cancelled : .ended
        case .select:
            chartDelegate?.candleChartGestureDidEndSelection(self)
            state = cancelled ? .cancelled : .ended
        }
    }
    
    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    private func recordVelocitySample(timestamp: TimeInterval, x: CGFloat) {
        velocitySamples.append(VelocitySample(timestamp: timestamp, x: x))
        let cutoff = timestamp - velocitySampleWindow
        velocitySamples.removeAll { $0.timestamp < cutoff }
    }
    
    // Samples older than the window before release are stale, e.g. the finger
    // paused after a fast swipe, so they must not produce a fling
    private func computeHorizontalVelocity(releaseTimestamp: TimeInterval) -> CGFloat {
        let cutoff = releaseTimestamp - velocitySampleWindow
        let samples = velocitySamples.filter { $0.timestamp >= cutoff }
        guard samples.count >= 2,
              let first = samples.first,
              let last = samples.last
        else {
            return 0
        }
        let dt = last.timestamp - first.timestamp
        guard dt > 0.005 else {
            return 0
        }
        return (last.x - first.x) / CGFloat(dt)
    }
    
    private func stopFling(notifyScrollingEnded: Bool) {
        let wasRunning = flingDisplayLink != nil
        flingDisplayLink?.invalidate()
        flingDisplayLink = nil
        flingVelocityX = 0
        lastFlingTimestamp = nil
        if wasRunning && notifyScrollingEnded {
            chartDelegate?.candleChartGesture(self, didChangeScrolling: false)
        }
    }
    
    fileprivate func stepFling(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt: CFTimeInterval
        if let lastFlingTimestamp {
            dt = min(1.0 / 30.0, max(0, now - lastFlingTimestamp))
        } else {
            dt = min(1.0 / 30.0, max(0, link.targetTimestamp - link.timestamp))
        }
        lastFlingTimestamp = now
        
        guard dt > 0 else {
            return
        }
        let deltaX = flingVelocityX * CGFloat(dt)
        let canContinue = chartDelegate?.candleChartGesture(self, didScrollBy: deltaX) ?? false
        flingVelocityX *= CGFloat(exp(-flingDecelerationRate * dt))
        if !canContinue || abs(flingVelocityX) < stopFlingVelocity {
            stopFling(notifyScrollingEnded: true)
        }
    }
    
    private func centroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else {
            return .zero
        }
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for p in points {
            sumX += p.x
            sumY += p.y
        }
        let count = CGFloat(points.count)
        return CGPoint(x: sumX / count, y: sumY / count)
    }
    
    private func averageSpan(of points: [CGPoint], centroid: CGPoint) -> CGFloat {
        guard !points.isEmpty else {
            return 0
        }
        var total: CGFloat = 0
        for p in points {
            total += hypot(p.x - centroid.x, p.y - centroid.y)
        }
        return total / CGFloat(points.count)
    }
    
}

extension CandleChartGestureRecognizer: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === self,
              otherGestureRecognizer is UIPanGestureRecognizer,
              let chartView = view,
              let otherView = otherGestureRecognizer.view,
              otherView !== chartView,
              otherView is UIScrollView,
              chartView.isDescendant(of: otherView)
        else {
            return false
        }
        return true
    }
    
}

private final class FlingDisplayLinkProxy {
    
    weak var target: CandleChartGestureRecognizer?
    
    init(target: CandleChartGestureRecognizer) {
        self.target = target
    }
    
    @objc func step(_ link: CADisplayLink) {
        target?.stepFling(link)
    }
    
}
