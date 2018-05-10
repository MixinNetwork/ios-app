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
            updateSeeMoreButton()
        }
    }
    var textColor = UIColor.black {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: textColor)
            updateSeeMoreButton()
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
    
    private lazy var seeMoreAttributedText = makeSeeMoreAttributedText()
    private lazy var seeMoreSize = ceil(seeMoreAttributedText.size())
    private lazy var seeMoreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setAttributedTitle(seeMoreAttributedText, for: .normal)
        button.addTarget(self, action: #selector(seeMoreAction(_:)), for: .touchUpInside)
        addSubview(button)
        return button
    }()
    
    private var normalContent: Content?
    private var normalTextSize = CGSize.zero
    private var collapsedContent: Content?
    private var collapsedTextSize = CGSize.zero
    
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
                let x1: CGFloat = 0
                let x2 = normalTextSize.width - seeMoreSize.width
                let x3 = normalTextSize.width
                let y1: CGFloat = 0
                let y2 = collapsedTextSize.height - seeMoreSize.height - font.descender
                let y3 = collapsedTextSize.height
                let collapsedPath = UIBezierPath()
                collapsedPath.move(to: CGPoint(x: x1, y: y1))
                collapsedPath.addLine(to: CGPoint(x: x3, y: y1))    // ┌─────────┐ y1
                collapsedPath.addLine(to: CGPoint(x: x3, y: y2))    // │         │
                collapsedPath.addLine(to: CGPoint(x: x2, y: y2))    // │     ┌───┘ y2
                collapsedPath.addLine(to: CGPoint(x: x2, y: y3))    // └─────┘     y3
                collapsedPath.addLine(to: CGPoint(x: x1, y: y3))    // x1   x2  x3
                collapsedPath.apply(coreTextTransform)
                collapsedPath.close()
                let collapsedFrame = CTFramesetterCreateFrame(framesetter, .zero, collapsedPath.cgPath, nil)
                let collapsedLines = CTFrameGetLines(collapsedFrame) as! [CTLine]
                let collapsedLineWidths = normalLines.map{ ceil(CTLineGetBoundsWithOptions($0, []).size.width) }
                var collapsedOrigins = [CGPoint](repeating: .zero, count: collapsedLines.count)
                CTFrameGetLineOrigins(collapsedFrame, .zero, &collapsedOrigins)
                switch self.textAlignment {
                case .left:
                    break
                case .center:
                    for (index, origin) in collapsedOrigins.enumerated() {
                        let x = max(0, (layoutSize.width - collapsedLineWidths[index]) / 2)
                        collapsedOrigins[index] = floor(CGPoint(x: x, y: origin.y))
                    }
                }
                let lastIndex = collapsedLines.count - 1
                let lastLineSize = CTLineGetBoundsWithOptions(collapsedLines[lastIndex], [])
                let lastLineWithSeeMoreButtonWidth = lastLineSize.width + seeMoreSize.width
                collapsedOrigins[lastIndex].x = (bounds.width - lastLineWithSeeMoreButtonWidth) / 2
                let collapsedLinks = links(fromLinksMap: linksMap, forLines: collapsedLines, lineOrigins: collapsedOrigins)
                collapsedContent = Content(lines: collapsedLines, lineOrigins: collapsedOrigins, links: collapsedLinks)
                let seeMoreButtonOrigin = CGPoint(x: collapsedOrigins[lastIndex].x + lastLineSize.width,
                                                  y: collapsedTextSize.height - seeMoreSize.height)
                seeMoreButton.frame = CGRect(origin: seeMoreButtonOrigin, size: seeMoreSize)
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
    
    private func makeSeeMoreAttributedText() -> NSAttributedString {
        let str = NSMutableAttributedString(string: "... ", attributes: [.font: font, .foregroundColor: textColor])
        str.append(NSAttributedString(string: Localized.ACTION_SEE_MORE, attributes: [.font: font, .foregroundColor: UIColor.systemTint]))
        return str.copy() as! NSAttributedString
    }
    
    private func updateSeeMoreButton() {
        seeMoreAttributedText = makeSeeMoreAttributedText()
        seeMoreSize = seeMoreAttributedText.size()
        seeMoreButton.setAttributedTitle(seeMoreAttributedText, for: .normal)
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
