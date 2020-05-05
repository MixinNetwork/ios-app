import UIKit

class ProfileDescriptionLabelLayer: CALayer {
    
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
    
}

class ProfileDescriptionLabel: CoreTextLabel {
    
    override static var layerClass: AnyClass {
        return ProfileDescriptionLabelLayer.self
    }
    
    var text = "" {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: text)
        }
    }
    var font = UIFont.systemFont(ofSize: 14) {
        didSet {
            typesetIfNeeded(oldValue: oldValue, newValue: font)
        }
    }
    var textColor = UIColor.text {
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
    
    override var bounds: CGRect {
        didSet {
            typesetIfNeeded(oldValue: bounds.width, newValue: oldValue.width, epsilon: 1)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return textSize
    }
    
    private let linkBackgroundCornerRadius: CGFloat =  4
    private let maxLineCount = 8
    
    private var textSize = CGSize.zero
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        typeset()
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
    
}

// MARK: - Private works
extension ProfileDescriptionLabel {
    
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
        guard !text.isEmpty else {
            content = nil
            textSize = .zero
            return
        }
        let str = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: str.mutableString.length)
        var linksMap = [NSRange: URL]()
        Link.detector.enumerateMatches(in: text, options: [], using: { (result, _, _) in
            guard let result = result, let url = result.url else {
                return
            }
            linksMap[result.range] = url
        })
        // Set attributes
        let desc = UIFontMetrics.default.scaledFont(for: font).fontDescriptor
        let ctFont = CTFontCreateWithFontDescriptor(desc as CTFontDescriptor, 0, nil)
        var textAlignment = self.textAlignment.ctTextAlignment.rawValue
        var lineBreakMode = self.lineBreakMode.rawValue
        var lineSpacing = self.lineSpacing
        var paragraphSpacing = self.paragraphSpacing
        var lineHeight = self.font.lineHeight
        
        let settings = withUnsafeBytes(of: &textAlignment) { (textAlignment) -> [CTParagraphStyleSetting] in
            withUnsafeBytes(of: &lineBreakMode) { (lineBreakMode) -> [CTParagraphStyleSetting] in
                withUnsafeBytes(of: &lineSpacing) { (lineSpacing) -> [CTParagraphStyleSetting] in
                    withUnsafeBytes(of: &paragraphSpacing) { (paragraphSpacing) -> [CTParagraphStyleSetting] in
                        withUnsafeBytes(of: &lineHeight) { (lineHeight) -> [CTParagraphStyleSetting] in
                            [CTParagraphStyleSetting(spec: .alignment,
                                                     valueSize: MemoryLayout<CTTextAlignment.RawValue>.size,
                                                     value: textAlignment.baseAddress!),
                             CTParagraphStyleSetting(spec: .lineBreakMode,
                                                     valueSize: MemoryLayout<CTLineBreakMode.RawValue>.size,
                                                     value: lineBreakMode.baseAddress!),
                             CTParagraphStyleSetting(spec: .minimumLineSpacing,
                                                     valueSize: MemoryLayout<CGFloat>.size,
                                                     value: lineSpacing.baseAddress!),
                             CTParagraphStyleSetting(spec: .maximumLineSpacing,
                                                     valueSize: MemoryLayout<CGFloat>.size,
                                                     value: lineSpacing.baseAddress!),
                             CTParagraphStyleSetting(spec: .paragraphSpacing,
                                                     valueSize: MemoryLayout<CGFloat>.size,
                                                     value: paragraphSpacing.baseAddress!),
                             CTParagraphStyleSetting(spec: .minimumLineHeight,
                                                     valueSize: MemoryLayout<CGFloat>.size,
                                                     value: lineHeight.baseAddress!)]
                        }
                    }
                }
            }
        }
        
        let paragraphStyle = CTParagraphStyleCreate(settings, settings.count)
        let attr: [NSAttributedString.Key: Any] = [
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
        let layoutSize = CGSize(width: bounds.width, height: UIView.layoutFittingExpandedSize.height)
        textSize = ceil(CTFramesetterSuggestFrameSizeWithConstraints(framesetter, .zero, nil, layoutSize, nil))
        textSize.height = min(font.lineHeight * CGFloat(maxLineCount), textSize.height)
        let path = CGPath(rect: CGRect(origin: .zero, size: textSize), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, .zero, path, nil)
        let lines = CTFrameGetLines(frame) as! [CTLine]
        let lineWidths = lines.map{ ceil(CTLineGetBoundsWithOptions($0, []).size.width) }
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, .zero, &origins)
        origins = origins.map(round)
        switch self.textAlignment {
        case .left:
            break
        case .center:
            for (index, origin) in origins.enumerated() {
                origins[index] = CGPoint(x: max(0, (layoutSize.width - lineWidths[index]) / 2),
                                         y: origin.y)
            }
        }
        
        let clampedLines = Array(lines.prefix(maxLineCount))
        let clampedOrigins = Array(origins.prefix(maxLineCount))
        let links = self.links(fromLinksMap: linksMap, forLines: clampedLines, lineOrigins: origins)
        content = Content(lines: clampedLines, lineOrigins: clampedOrigins, links: links)
        
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }
    
    private func links(fromLinksMap linksMap: [NSRange: URL], forLines lines: [CTLine], lineOrigins: [CGPoint]) -> [Link] {
        var links = [Link]()
        for link in linksMap {
            let linkRects: [CGRect] = lines.enumerated().compactMap({ (index, line) -> CGRect? in
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
extension ProfileDescriptionLabel {
    
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
