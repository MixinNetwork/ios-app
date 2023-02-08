import UIKit
import MixinServices

class FontSizeSlider: UIControl {
    
    private(set) var fontSize: ChatFontSize = .regular
    
    private let feedback = UISelectionFeedbackGenerator()
    private let track = CAShapeLayer()
    private let thumb = CAShapeLayer()
    private var marks = [CAShapeLayer]()
    private let markSize = CGSize(width: 4, height: 12)
    private let marksCount = 7
    private let trackHeight = 4.0
    private let thumbRadius = 12.0
    private let thumbTintColor = UIColor.white
    private let maximumTrackTintColor = UIColor.theme
    private let minimumTrackTintColor = R.color.text_accessory()!
    private let disableTrackTintColor = R.color.line()!
    private let transactionDuration = CATransaction.animationDuration()
    
    private var currentIndex = 3
    private var startTouchPosition = CGPoint.zero
    private var startThumbPosition = CGPoint.zero
    
    private var thumbPosition: CGFloat {
        thumb.position.x - thumbRadius
    }
    
    private var thumbIndex: Int {
        let width = track.bounds.size.width
        if width == 0 {
            return 0
        } else {
            return Int(round(thumbPosition / (width / CGFloat(marksCount - 1))))
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutLayers(animated: true)
    }
    
    func updateUserInteraction(enabled: Bool, animated: Bool) {
        isUserInteractionEnabled = enabled
        layoutLayers(animated: animated)
    }
    
    func updateFontSize(_ fontSize: ChatFontSize) {
        currentIndex = fontSize.rawValue
    }
    
}

extension FontSizeSlider {
    
    private func prepare() {
        thumb.shadowColor = UIColor.black.withAlphaComponent(0.06).cgColor
        thumb.shadowOpacity = 1
        thumb.shadowRadius = 10
        thumb.shadowOffset = CGSize(width: 0, height: 0.5)
        layer.addSublayer(thumb)
        layer.addSublayer(track)
        layoutLayers(animated: false)
    }
    
    private func layoutLayers(animated: Bool) {
        let indexDiff = thumbIndex - currentIndex
        let moveThumbToLeft = indexDiff < 0
        let thumbDiameter = thumbRadius * 2
        let contentWidth = bounds.size.width - thumbDiameter
        let stepWidth = contentWidth / CGFloat(marksCount - 1)
        let cententFrameY = (bounds.size.height - thumbDiameter) / 2
        let contentFrame = CGRect(x: thumbRadius, y: cententFrameY, width: contentWidth, height: thumbDiameter)
        let oldPath = track.path
        let oldPosition = thumb.position
        let thumbDrawRect = CGRect(x: 0, y: 0, width: thumbDiameter, height: thumbDiameter)
        if !animated {
            CATransaction.begin()
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        }
        thumb.frame.size = thumbDrawRect.size
        thumb.path = UIBezierPath(roundedRect: thumbDrawRect, cornerRadius: thumbRadius).cgPath
        thumb.fillColor = thumbTintColor.cgColor
        thumb.position = CGPoint(x: contentFrame.origin.x + stepWidth * CGFloat(currentIndex), y: contentFrame.midY)
        track.frame = CGRect(x: contentFrame.origin.x, y: contentFrame.midY - trackHeight / 2, width: contentFrame.size.width, height: trackHeight)
        track.path = trackPath()
        track.fillColor = isUserInteractionEnabled ? maximumTrackTintColor.cgColor : disableTrackTintColor.cgColor
        track.backgroundColor = isUserInteractionEnabled ? minimumTrackTintColor.cgColor : disableTrackTintColor.cgColor
        if animated {
            let thumbAnimation = CABasicAnimation(keyPath: "position")
            thumbAnimation.duration = transactionDuration
            thumbAnimation.fromValue = NSValue(cgPoint: oldPosition)
            thumb.add(thumbAnimation, forKey: "position")
            let trackAnimation = CABasicAnimation(keyPath: "path")
            trackAnimation.duration = transactionDuration
            trackAnimation.fromValue = oldPath
            track.add(trackAnimation, forKey: "path")
        }
        let animationDuration = markSize.width / track.bounds.width
        let animationTimeDiff = (moveThumbToLeft ? transactionDuration : -transactionDuration) / abs(CGFloat(indexDiff))
        var animationBeginTime = moveThumbToLeft ? animationTimeDiff : transactionDuration + animationTimeDiff
        for index in 0..<marksCount {
            let mark = mark(at: index)
            mark.bounds.size = markSize
            mark.position = CGPoint(x: contentFrame.origin.x + stepWidth * CGFloat(index), y: contentFrame.midY)
            mark.path = UIBezierPath(rect: mark.bounds).cgPath
            if animated {
                let newColor = markColor(mark)
                let oldColor = mark.fillColor
                if newColor != oldColor {
                    let animation = CABasicAnimation(keyPath: "kTrackAnimation")
                    animation.fillMode = .backwards
                    animation.beginTime = CACurrentMediaTime() + animationBeginTime
                    animation.duration = transactionDuration * animationDuration
                    animation.keyPath = "fillColor"
                    animation.fromValue = oldColor
                    animation.toValue = newColor
                    mark.add(animation, forKey: "kTrackAnimation")
                    mark.setValue(animation.toValue, forKey: "fillColor")
                    animationBeginTime += animationTimeDiff
                }
            } else {
                mark.fillColor = markColor(mark)
            }
        }
        if !animated {
            CATransaction.commit()
        }
        thumb.removeFromSuperlayer()
        layer.addSublayer(thumb)
    }
    
    private func markColor(_ mark: CAShapeLayer) -> CGColor {
        guard isUserInteractionEnabled else {
            return disableTrackTintColor.cgColor
        }
        if thumbPosition >= mark.position.x - thumbRadius {
            return maximumTrackTintColor.cgColor
        } else {
            return minimumTrackTintColor.cgColor
        }
    }
    
    private func mark(at index: Int) -> CAShapeLayer {
        let mark: CAShapeLayer
        if index < marks.count {
            mark = marks[index]
        } else {
            mark = CAShapeLayer()
            layer.addSublayer(mark)
            marks.append(mark)
        }
        return mark
    }
    
    private func endTouches() {
        let newIndex = thumbIndex
        if newIndex != currentIndex {
            currentIndex = newIndex
            didChangeFontSize()
        }
        setNeedsLayout()
    }
    
    private func trackPath() -> CGPath {
        let fillRect = CGRect(origin: .zero, size: CGSize(width: thumbPosition, height: track.bounds.height))
        return UIBezierPath(rect: fillRect).cgPath
    }
    
    private func didChangeFontSize() {
        fontSize = ChatFontSize(rawValue: currentIndex) ?? .regular
        sendActions(for: .valueChanged)
        feedback.selectionChanged()
        feedback.prepare()
    }
    
}

extension FontSizeSlider {
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        startTouchPosition = touch.location(in: self)
        startThumbPosition = thumb.position
        if thumb.frame.contains(startTouchPosition) {
            return true
        }
        for (index, mark) in marks.enumerated() {
            let validMarkTouchFrame = mark.frame.insetBy(dx: -14, dy: -10)
            if validMarkTouchFrame.contains(startTouchPosition) {
                let oldIndex = currentIndex
                currentIndex = index
                if oldIndex != index {
                    didChangeFontSize()
                }
                setNeedsLayout()
                return false
            }
        }
        return false
    }
    
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let position = startThumbPosition.x - (startTouchPosition.x - touch.location(in: self).x)
        let limitedPosition = min(max(thumbRadius, position), bounds.width - thumbRadius)
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        thumb.position.x = limitedPosition
        track.path = trackPath()
        let newIndex = thumbIndex
        marks.forEach { $0.fillColor = markColor($0) }
        if currentIndex != newIndex {
            currentIndex = newIndex
            didChangeFontSize()
        }
        CATransaction.commit()
        return true
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        endTouches()
    }
    
    override func cancelTracking(with event: UIEvent?) {
        endTouches()
    }
    
}
