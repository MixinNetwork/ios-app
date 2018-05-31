import UIKit

protocol CollapsingLabelDelegate: CoreTextLabelDelegate {
    func collapsingLabel(_ label: CollapsingLabel, didChangeModeTo newMode: CollapsingLabel.Mode)
}

class CollapsingLabelLayer: CALayer {
    
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
    
}

class CollapsingLabel: CoreTextLabel {
    
    override static var layerClass: AnyClass {
        return CollapsingLabelLayer.self
    }
    
    var mode = Mode.collapsed {
        didSet {
            guard mode != oldValue else {
                return
            }
            if mode == .normal {
                seeMoreButton.isHidden = true
            } else {
                seeMoreButton.isHidden = !(normalTextSize.height - collapsedTextSize.height > 1)
            }
            setNeedsDisplay()
            invalidateIntrinsicContentSize()
            (delegate as? CollapsingLabelDelegate)?.collapsingLabel(self, didChangeModeTo: mode)
        }
    }
    var text = "" {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: text)
        }
    }
    var font = UIFont.systemFont(ofSize: 16) {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: font)
        }
    }
    var textColor = UIColor.darkGray {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: textColor)
        }
    }
    var linkColor = UIColor.systemTint {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: linkColor)
        }
    }
    var textAlignment = TextAlignment.center {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: textAlignment)
        }
    }
    var lineBreakMode = CTLineBreakMode.byWordWrapping {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: lineBreakMode)
        }
    }
    var lineSpacing: CGFloat = 0 {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: lineSpacing)
        }
    }
    var paragraphSpacing: CGFloat = 0 {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: paragraphSpacing)
        }
    }
    var maxLineNumberWhenCollapsed = 3 {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: maxLineNumberWhenCollapsed)
        }
    }
    
    override var content: CoreTextLabel.Content? {
        get {
            return mode == .normal ? normalContent : collapsedContent
        }
        set {
            fatalError("Do not set this var directly. Use CollapsingLabel.text instead.")
        }
    }
    
    override var bounds: CGRect {
        didSet {
            typesetIfNeeded(oldValue: bounds.width, newValue: oldValue.width, epsilon: 1)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return mode == .normal ? normalTextSize : collapsedTextSize
    }
    
    private let linkBackgroundCornerRadius: CGFloat =  4
    
    private lazy var seeMoreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .bottom
        button.adjustsImageWhenHighlighted = false
        button.setImage(#imageLiteral(resourceName: "profile_mask_white"), for: .normal)
        button.addTarget(self, action: #selector(seeMoreAction(_:)), for: .touchUpInside)
        addSubview(button)
        return button
    }()
    
    private var normalContent: Content?
    private var normalTextSize = CGSize.zero
    private var collapsedContent: Content?
    private var collapsedTextSize = CGSize.zero
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if selectedLink == nil {
            if UIMenuController.shared.isMenuVisible {
                UIMenuController.shared.setMenuVisible(false, animated: true)
            } else {
                perform(#selector(showCopyMenu), with: nil, afterDelay: longPressDuration)
            }
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:))
    }
    
    @objc private func showCopyMenu() {
        becomeFirstResponder()
        UIMenuController.shared.setTargetRect(bounds, in: self)
        UIMenuController.shared.setMenuVisible(true, animated: true)
    }
    
    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = text
    }
    
    @objc private func seeMoreAction(_ sender: Any) {
        mode = .normal
    }
    
}

// MARK: - Private works
extension CollapsingLabel {
    
    private func typesetIfNeeded(oldValue: CGFloat, newValue: CGFloat, epsilon: CGFloat = 0.1) {
        guard abs(oldValue - newValue) > epsilon else {
            return
        }
        typeset()
    }
    
    private func typesetIfNeeded<T: Equatable>(oldValue: T, newValue: T) {
        guard oldValue != newValue else {
            return
        }
        typeset()
    }
    
    private func typeset() {
        if text.isEmpty {
            normalContent = nil
            collapsedContent = nil
            normalTextSize = .zero
            collapsedTextSize = .zero
        } else {
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            var linksMap = [NSRange: URL]()
            if let matches = Link.detector?.matches(in: text, options: [], range: fullRange) {
                for match in matches {
                    linksMap[match.range] = match.url
                }
            }
            // Set attributes
            let str = NSMutableAttributedString(string: text)
            let ctFont = CTFontCreateWithFontDescriptor(font.fontDescriptor as CTFontDescriptor, 0, nil)
            var textAlignment = self.textAlignment.ctTextAlignment.rawValue
            var lineBreakMode = self.lineBreakMode.rawValue
            var lineSpacing = self.lineSpacing
            var paragraphSpacing = self.paragraphSpacing
            var lineHeight = self.font.lineHeight
            let settings = [CTParagraphStyleSetting(spec: .alignment,
                                                    valueSize: MemoryLayout<CTTextAlignment>.size,
                                                    value: &textAlignment),
                            CTParagraphStyleSetting(spec: .lineBreakMode,
                                                    valueSize: MemoryLayout<CTLineBreakMode>.size,
                                                    value: &lineBreakMode),
                            CTParagraphStyleSetting(spec: .minimumLineSpacing,
                                                    valueSize: MemoryLayout<CGFloat>.size,
                                                    value: &lineSpacing),
                            CTParagraphStyleSetting(spec: .maximumLineSpacing,
                                                    valueSize: MemoryLayout<CGFloat>.size,
                                                    value: &lineSpacing),
                            CTParagraphStyleSetting(spec: .paragraphSpacing,
                                                    valueSize: MemoryLayout<CGFloat>.size,
                                                    value: &paragraphSpacing),
                            CTParagraphStyleSetting(spec: .minimumLineHeight,
                                                    valueSize: MemoryLayout<CGFloat>.size,
                                                    value: &lineHeight)]
            let paragraphStyle = CTParagraphStyleCreate(settings, settings.count)
            let attr: [NSAttributedStringKey: Any] = [
                .ctFont: ctFont,
                .ctParagraphStyle: paragraphStyle,
                .ctForegroundColor: textColor.cgColor
            ]
            str.setAttributes(attr, range: fullRange)
            for range in linksMap.keys {
                str.setCTForegroundColor(linkColor, for: range)
            }
            // Make CTLine and Origins
            let framesetter = CTFramesetterCreateWithAttributedString(str as CFAttributedString)
            let layoutSize = CGSize(width: bounds.width, height: UILayoutFittingExpandedSize.height)
            normalTextSize = ceil(CTFramesetterSuggestFrameSizeWithConstraints(framesetter, .zero, nil, layoutSize, nil))
            let normalPath = CGPath(rect: CGRect(origin: .zero, size: normalTextSize), transform: nil)
            let normalFrame = CTFramesetterCreateFrame(framesetter, .zero, normalPath, nil)
            let normalLines = CTFrameGetLines(normalFrame) as! [CTLine]
            let normalLineWidths = normalLines.map{ ceil(CTLineGetBoundsWithOptions($0, []).size.width) }
            var normalOrigins = [CGPoint](repeating: .zero, count: normalLines.count)
            CTFrameGetLineOrigins(normalFrame, .zero, &normalOrigins)
            normalOrigins = normalOrigins.map{ round($0) }
            switch self.textAlignment {
            case .left:
                break
            case .center:
                for (index, origin) in normalOrigins.enumerated() {
                    normalOrigins[index] = CGPoint(x: max(0, (layoutSize.width - normalLineWidths[index]) / 2),
                                                   y: origin.y)
                }
            }
            let normalLinks = links(fromLinksMap: linksMap, forLines: normalLines, lineOrigins: normalOrigins)
            normalContent = Content(lines: normalLines, lineOrigins: normalOrigins, links: normalLinks)
            if normalLines.count <= maxLineNumberWhenCollapsed {
                collapsedContent = normalContent
                collapsedTextSize = normalTextSize
                seeMoreButton.isHidden = true
            } else {
                collapsedTextSize = CGSize(width: bounds.width, height: ceil(CGFloat(maxLineNumberWhenCollapsed) * font.lineHeight))
                let collapsedLines = Array(normalLines.prefix(maxLineNumberWhenCollapsed))
                let collapsedOrigins = Array(normalOrigins.prefix(maxLineNumberWhenCollapsed))
                    .map{ CGPoint(x: $0.x, y: $0.y + (collapsedTextSize.height - normalTextSize.height))}
                let collapsedLinks = links(fromLinksMap: linksMap, forLines: collapsedLines, lineOrigins: collapsedOrigins)
                collapsedContent = Content(lines: collapsedLines, lineOrigins: collapsedOrigins, links: collapsedLinks)
                seeMoreButton.frame = CGRect(origin: .zero, size: collapsedTextSize)
                seeMoreButton.isHidden = mode == .normal
            }
        }
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }
    
    private func links(fromLinksMap linksMap: [NSRange: URL], forLines lines: [CTLine], lineOrigins: [CGPoint]) -> [Link] {
        var links = [Link]()
        for link in linksMap {
            let linkRects: [CGRect] = lines.enumerated().flatMap({ (index, line) -> CGRect? in
                let lineOrigin = lineOrigins[index]
                let cfLineRange = CTLineGetStringRange(line)
                let lineRange = NSRange(cfRange: cfLineRange)
                if let intersection = lineRange.intersection(link.key) {
                    return line.frame(forRange: intersection, lineOrigin: lineOrigin)
                } else {
                    return nil
                }
            })
            var path: UIBezierPath?
            for linkRect in linkRects {
                let newPath = UIBezierPath(roundedRect: linkRect, cornerRadius: linkBackgroundCornerRadius)
                if path != nil {
                    path!.append(newPath)
                } else {
                    path = newPath
                }
            }
            if let path = path {
                links += linkRects.map{ Link(hitFrame: $0, backgroundPath: path, url: link.value) }
            }
        }
        return links
    }
    
}

// MARK: - Embedded class
extension CollapsingLabel {
    
    enum Mode {
        case collapsed
        case normal
    }
    
    enum TextAlignment {
        case left
        case center
        
        var ctTextAlignment: CTTextAlignment {
            switch self {
            case .left:
                return .left
            case .center:
                return .center
            }
        }
    }
    
}
