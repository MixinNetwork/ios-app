import UIKit

final class IdentityNumberLabel: UILabel {
    
    var identityNumber: String? {
        didSet {
            if let id = identityNumber {
                text = Localized.PROFILE_MIXIN_ID(id: id)
            } else {
                text = nil
            }
        }
    }
    
    var highlightIdentityNumber = false {
        didSet {
            if highlightIdentityNumber && !oldValue {
                setHighlighted(true)
            } else if !highlightIdentityNumber && oldValue {
                setHighlighted(false)
            }
        }
    }
    
    var highlightedRect: CGRect? {
        if highlightIdentityNumber && text != nil && identityNumber != nil {
            return highlightedBackgroundView?.frame
        } else {
            return nil
        }
    }
    
    private var highlightedBackgroundView: UIView?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutSelectedBackgroundViewIfNeeded()
    }
    
    private func layoutSelectedBackgroundViewIfNeeded() {
        guard let highlightedBackgroundView = highlightedBackgroundView, highlightedBackgroundView.superview == self else {
            return
        }
        guard let text = text, let attributedText = attributedText else {
            return
        }
        guard let identityNumber = identityNumber else {
            return
        }
        let idRange = (text as NSString).range(of: identityNumber)
        let invalidRange = NSRange(location: NSNotFound, length: 0)
        guard idRange != invalidRange else {
            return
        }
        let textContainer = NSTextContainer(size: bounds.size)
        textContainer.lineFragmentPadding = 0
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        let textStorage = NSTextStorage(attributedString: attributedText)
        textStorage.addLayoutManager(layoutManager)
        var idGlyphRange = invalidRange
        layoutManager.characterRange(forGlyphRange: idRange, actualGlyphRange: &idGlyphRange)
        guard idGlyphRange != invalidRange else {
            return
        }
        let idRect = layoutManager.boundingRect(forGlyphRange: idGlyphRange, in: textContainer)
        let standardized = CGRect(x: floor(idRect.origin.x), y: floor(idRect.origin.y), width: ceil(idRect.width), height: ceil(idRect.height))
        highlightedBackgroundView.frame = standardized.insetBy(dx: -1, dy: 0)
    }
    
    private func setHighlighted(_ highlighted: Bool) {
        if highlighted {
            let highlightedBackgroundView: UIView
            if let view = self.highlightedBackgroundView {
                highlightedBackgroundView = view
            } else {
                highlightedBackgroundView = UIView()
                highlightedBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.1)
                highlightedBackgroundView.clipsToBounds = true
                highlightedBackgroundView.layer.cornerRadius = 2
                self.highlightedBackgroundView = highlightedBackgroundView
                addSubview(highlightedBackgroundView)
            }
            highlightedBackgroundView.alpha = 0
            UIView.animate(withDuration: 0.3) {
                highlightedBackgroundView.alpha = 1
            }
            setNeedsLayout()
            layoutIfNeeded()
        } else {
            if let highlightedBackgroundView = highlightedBackgroundView {
                UIView.animate(withDuration: 0.3) {
                    highlightedBackgroundView.alpha = 0
                }
            }
        }
    }
    
}
