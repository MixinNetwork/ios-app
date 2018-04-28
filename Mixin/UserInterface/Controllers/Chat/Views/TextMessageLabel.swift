import UIKit

protocol TextMessageLabelDelegate: class {
    func textMessageLabel(_ label: TextMessageLabel, didSelectURL url: URL)
    func textMessageLabel(_ label: TextMessageLabel, didLongPressOnURL url: URL)
}

class TextMessageLabel: UIView {

    static let gestureRecognizerBypassingDelegateObject = GestureRecognizerBypassingDelegateObject()
    
    weak var delegate: TextMessageLabelDelegate?
    
    var lines = [CTLine]()
    var lineOrigins = [CGPoint]()
    var highlightPaths = [UIBezierPath]()
    var links = [TextMessageViewModel.Link]()

    private let highlightColor = UIColor.messageKeywordHighlight
    private let longPressDuration: TimeInterval = 0.5
    
    private var selectedLink: TextMessageViewModel.Link?
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return
        }
        ctx.saveGState()
        ctx.concatenate(coreTextTransform)
        highlightColor.setFill()
        for path in highlightPaths {
            path.fill()
        }
        assert(lines.count == lineOrigins.count)
        if let link = selectedLink {
            UIColor.selectedLinkBackground.setFill()
            link.backgroundPath.fill()
        }
        for i in 0..<lines.count {
            ctx.textPosition = lineOrigins[i]
            CTLineDraw(lines[i], ctx)
        }
        ctx.restoreGState()
    }
    
    func canResponseTouch(at point: CGPoint) -> Bool {
        for link in links {
            if link.hitFrame.applying(coreTextTransform).contains(point) {
                return true
            }
        }
        return false
    }
    
    private var coreTextTransform: CGAffineTransform {
        return CGAffineTransform(translationX: 0, y: bounds.height).scaledBy(x: 1, y: -1)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else {
            return
        }
        let point = touch.location(in: self)
        guard bounds.contains(point) else {
            return
        }
        if let link = links.first(where: { $0.hitFrame.applying(coreTextTransform).contains(point) }) {
            selectedLink = link
            setNeedsDisplay()
            perform(#selector(invokeLongPressAction), with: nil, afterDelay: longPressDuration)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else {
            return
        }
        let point = touch.location(in: self)
        guard bounds.contains(point) else {
            return
        }
        if let link = links.first(where: { $0.hitFrame.applying(coreTextTransform).contains(point) }) {
            selectedLink = link
            setNeedsDisplay()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        if selectedLink != nil {
            selectedLink = nil
            setNeedsDisplay()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        guard let touch = touches.first else {
            return
        }
        if selectedLink != nil {
            let point = touch.location(in: self)
            if bounds.contains(point), let link = links.first(where: { $0.hitFrame.applying(coreTextTransform).contains(point) }) {
                delegate?.textMessageLabel(self, didSelectURL: link.url)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                self.selectedLink = nil
                self.setNeedsDisplay()
            })
        }
    }
    
    @objc func invokeLongPressAction() {
        guard let url = selectedLink?.url else {
            return
        }
        delegate?.textMessageLabel(self, didLongPressOnURL: url)
        selectedLink = nil
        setNeedsDisplay()
        let superview = self.superview
        removeFromSuperview()
        superview?.addSubview(self)
    }
    
    class GestureRecognizerBypassingDelegateObject: NSObject, UIGestureRecognizerDelegate {
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let label = touch.view as? TextMessageLabel else {
                return true
            }
            return !label.canResponseTouch(at: touch.location(in: label))
        }
        
    }

}
