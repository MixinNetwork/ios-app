import UIKit

protocol CollapsingTextViewDelegate: class {
    func collapsingTextView(_ textView: CollapsingTextView, didChangeModeTo mode: CollapsingTextView.Mode)
}

class CollapsingTextView: UITextView {
    
    enum Mode {
        case normal
        case collapsed
    }
    
    weak var collapsingTextViewDelegate: CollapsingTextViewDelegate?
    var mode = Mode.collapsed {
        didSet {
            layout()
            collapsingTextViewDelegate?.collapsingTextView(self, didChangeModeTo: mode)
        }
    }
    
    private let maximumNumberOfLinesWhenCollapsed = 3
    private let seeMoreButton = UIButton()
    private let truncationLayoutTextContianer = NSTextContainer()
    private var truncationTextStorage: NSTextStorage!
    private var truncationLayoutManager: NSLayoutManager!
    private var fullAttributedText: NSAttributedString!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        prepare()
    }
    
    override var attributedText: NSAttributedString! {
        get {
            return fullAttributedText ?? super.attributedText
        }
        set {
            fullAttributedText = newValue
            super.attributedText = newValue
            if truncationLayoutManager != nil {
                truncationTextStorage = NSTextStorage(attributedString: attributedText)
                truncationTextStorage.addLayoutManager(truncationLayoutManager)
                layout()
            }
        }
    }
    
    override var bounds: CGRect {
        didSet {
            if abs(bounds.width - oldValue.width) > 1 {
                layout()
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return seeMoreButton.frame.contains(point) ? seeMoreButton : nil
    }
    
    @objc func showMoreAction(_ sender: Any) {
        mode = .normal
    }
    
    private func prepare() {
        let font = self.font ?? .systemFont(ofSize: 15)
        let seeMore = NSMutableAttributedString(string: " ... ", attributes: [.font: font, .foregroundColor: UIColor.black])
        seeMore.append(NSAttributedString(string: Localized.ACTION_SEE_MORE, attributes: [.font: font, .foregroundColor: UIColor.systemTint]))
        seeMoreButton.setAttributedTitle(seeMore, for: .normal)
        seeMoreButton.addTarget(self, action: #selector(showMoreAction(_:)), for: .touchUpInside)
        seeMoreButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        addSubview(seeMoreButton)
        truncationLayoutManager = NSLayoutManager()
        truncationTextStorage = NSTextStorage(attributedString: attributedText)
        truncationTextStorage.addLayoutManager(truncationLayoutManager)
        truncationLayoutTextContianer.size = UIEdgeInsetsInsetRect(bounds, textContainerInset).size
        truncationLayoutTextContianer.lineFragmentPadding = textContainer.lineFragmentPadding
        truncationLayoutManager.addTextContainer(truncationLayoutTextContianer)
        layout()
    }
    
    private func layout() {
        if mode == .normal {
            super.attributedText = fullAttributedText
            seeMoreButton.isHidden = true
        } else {
            layoutManager.ensureLayout(for: textContainer)
            truncationLayoutTextContianer.size = CGSize(width: textContainer.size.width,
                                                        height: UILayoutFittingExpandedSize.height)
            var shouldTruncate = false
            var numberOfLines = 0
            var index = 0
            var lineBeforeIndex = 0
            let numberOfGlyphs = truncationLayoutManager.numberOfGlyphs
            var range = NSRange()
            while index < numberOfGlyphs {
                numberOfLines += 1
                shouldTruncate = numberOfLines > maximumNumberOfLinesWhenCollapsed
                if shouldTruncate {
                    super.attributedText = fullAttributedText
                    invalidateIntrinsicContentSize()
                    setNeedsLayout()
                    layoutIfNeeded()
                    if let lastLineStartPosition = position(from: beginningOfDocument, offset: lineBeforeIndex), let lastLineEndPosition = position(from: lastLineStartPosition, offset: index - lineBeforeIndex), let lastLineRange = textRange(from: lastLineStartPosition, to: lastLineEndPosition) {
                        let seeMoreSize = seeMoreButton.intrinsicContentSize
                        let lastLineRect = firstRect(for: lastLineRange)
                        let seeMoreButtonTopLeftPoint = CGPoint(x: bounds.width - seeMoreSize.width, y: lastLineRect.maxY - seeMoreSize.height)
                        if let position = closestPosition(to: seeMoreButtonTopLeftPoint, within: lastLineRange) {
                            let seeMoreOrigin = CGPoint(x: caretRect(for: position).origin.x, y: lastLineRect.maxY - seeMoreSize.height)
                            seeMoreButton.frame = CGRect(origin: seeMoreOrigin, size: seeMoreSize)
                            let visibleRange = NSRange(location: 0, length: offset(from: beginningOfDocument, to: position))
                            super.attributedText = fullAttributedText?.attributedSubstring(from: visibleRange)
                        }
                    }
                    break
                } else {
                    lineBeforeIndex = index
                    truncationLayoutManager.lineFragmentRect(forGlyphAt: index, effectiveRange: &range)
                    index = NSMaxRange(range)
                }
            }
            seeMoreButton.isHidden = !shouldTruncate
        }
    }
    
}
