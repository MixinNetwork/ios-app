import UIKit

protocol CoreTextLabelDelegate: class {
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL)
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL)
}

extension CoreTextLabelDelegate {
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) { }
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) { }
}

class CoreTextLabel: UIView {
    
    struct Content {
        let lines: [CTLine]
        let lineOrigins: [CGPoint]
        let links: [Link]
    }
    
    weak var delegate: CoreTextLabelDelegate?
    
    var content: Content?
    var coreTextTransform: CGAffineTransform {
        return CGAffineTransform(translationX: 0, y: bounds.height).scaledBy(x: 1, y: -1)
    }
    
    private let longPressDuration: TimeInterval = 0.5
    
    private var selectedLink: Link?
    private var stopRespondingTouches = false
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), let content = content else {
            return
        }
        ctx.saveGState()
        ctx.concatenate(coreTextTransform)
        additionalDrawings()
        assert(content.lines.count == content.lineOrigins.count)
        if let link = selectedLink {
            UIColor.selectedLinkBackground.setFill()
            link.backgroundPath.fill()
        }
        for i in 0..<content.lines.count {
            ctx.textPosition = content.lineOrigins[i]
            CTLineDraw(content.lines[i], ctx)
        }
        ctx.restoreGState()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first, let content = content else {
            return
        }
        let point = touch.location(in: self)
        guard bounds.contains(point) else {
            return
        }
        if let link = content.links.first(where: { $0.hitFrame.applying(coreTextTransform).contains(point) }) {
            selectedLink = link
            setNeedsDisplay()
            perform(#selector(invokeLongPressAction), with: nil, afterDelay: longPressDuration)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard !stopRespondingTouches, let touch = touches.first, let content = content else {
            return
        }
        let point = touch.location(in: self)
        guard bounds.contains(point) else {
            return
        }
        if let link = content.links.first(where: { $0.hitFrame.applying(coreTextTransform).contains(point) }), link !== selectedLink {
            selectedLink = nil
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
        stopRespondingTouches = false
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        stopRespondingTouches = false
        guard let touch = touches.first, let content = content else {
            return
        }
        if selectedLink != nil {
            if !stopRespondingTouches {
                let point = touch.location(in: self)
                if bounds.contains(point), let link = content.links.first(where: { $0.hitFrame.applying(coreTextTransform).contains(point) }) {
                    delegate?.coreTextLabel(self, didSelectURL: link.url)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                self.selectedLink = nil
                self.setNeedsDisplay()
            })
        }
    }
    
    func additionalDrawings() {
        
    }
    
    @objc func invokeLongPressAction() {
        guard let url = selectedLink?.url else {
            return
        }
        delegate?.coreTextLabel(self, didLongPressOnURL: url)
        selectedLink = nil
        setNeedsDisplay()
        stopRespondingTouches = true
    }
    
}
