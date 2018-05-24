import UIKit

class TextMessageViewModel: DetailInfoMessageViewModel {
    
    struct Link {
        let hitFrame: CGRect
        let backgroundPath: UIBezierPath
        let url: URL
    }
    
    static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    
    private(set) var lines = [CTLine]()
    private(set) var lineOrigins = [CGPoint]()
    private(set) var links = [Link]()
    private(set) var contentLabelFrame = CGRect.zero
    private(set) var highlightPaths = [UIBezierPath]()
    
    var textColor: UIColor {
        return .black
    }
    
    private let timeLeftMargin: CGFloat = 20
    
    private let minimumTextSize = CGSize(width: 5, height: 18)
    private let font = UIFont.systemFont(ofSize: 16)
    private let linkColor = UIColor.systemTint
    private let textAlignment = CTTextAlignment.left
    private let lineBreakMode = CTLineBreakMode.byWordWrapping
    private let lineSpacing: CGFloat = 0
    private let paragraphSpacing: CGFloat = 0
    private let hightlightPathCornerRadius: CGFloat = 4
    
    private var textSize = CGSize.zero
    private var contentSize = CGSize.zero // contentSize is textSize concatenated with additionalTrailingSize and fullname width
    
    override var debugDescription: String {
        return super.debugDescription + ", textSize: \(textSize), contentSize: \(contentSize), contentLength: \(message.content.count)"
    }

    // Link detection will be disabled if subclasses override this var and return a non-nil value
    internal var fixedLinks: [NSRange: URL]? {
        return nil
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        super.init(message: message, style: style, fits: layoutWidth)
        let text: String
        // Detect links
        var links = [NSRange: (url: URL, color: UIColor?)]()
        if let fixedLinks = fixedLinks {
            text = message.content
            for (key, value) in fixedLinks {
                links[key] = (value, nil)
            }
        } else {
            let (usernameExtractedText, username) = EmbeddedUsernameDetector.stringByExtractingEmbeddedUsername(in: message.content)
            text = usernameExtractedText
            let textLength = (text as NSString).length
            let linkDetectionRange: NSRange
            if let username = username {
                links[username.range] = (url: username.url, color: username.color)
                let location = NSMaxRange(username.range)
                linkDetectionRange = NSRange(location: min(textLength, location), length: max(0, textLength - location))
            } else {
                linkDetectionRange = NSRange(location: 0, length: textLength)
            }
            if let matches = TextMessageViewModel.linkDetector?.matches(in: text, options: [], range: linkDetectionRange) {
                for match in matches {
                    guard let url = match.url else {
                        continue
                    }
                    links[match.range] = (url: url, color: nil)
                }
            }
        }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        // Set attributes
        let str = NSMutableAttributedString(string: text)
        let ctFont = CTFontCreateWithFontDescriptor(font.fontDescriptor as CTFontDescriptor, 0, nil)
        var textAlignment = self.textAlignment.rawValue
        var lineBreakMode = self.lineBreakMode.rawValue
        var lineSpacing = self.lineSpacing
        var paragraphSpacing = self.paragraphSpacing
        var lineHeight = self.font.lineHeight
        let settings = [CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: &textAlignment),
                        CTParagraphStyleSetting(spec: .lineBreakMode, valueSize: MemoryLayout<CTLineBreakMode>.size, value: &lineBreakMode),
                        CTParagraphStyleSetting(spec: .minimumLineSpacing, valueSize: MemoryLayout<CGFloat>.size, value: &lineSpacing),
                        CTParagraphStyleSetting(spec: .maximumLineSpacing, valueSize: MemoryLayout<CGFloat>.size, value: &lineSpacing),
                        CTParagraphStyleSetting(spec: .paragraphSpacing, valueSize: MemoryLayout<CGFloat>.size, value: &paragraphSpacing),
                        CTParagraphStyleSetting(spec: .minimumLineHeight, valueSize: MemoryLayout<CGFloat>.size, value: &lineHeight)]
        let paragraphStyle = CTParagraphStyleCreate(settings, settings.count)
        let attr: [NSAttributedStringKey: Any] = [
            .ctFont: ctFont,
            .ctParagraphStyle: paragraphStyle,
            .ctForegroundColor: textColor.cgColor
        ]
        str.setAttributes(attr, range: fullRange)
        for link in links {
            str.setColor(link.value.color ?? linkColor, for: link.key)
        }
        // Make CTLine and Origins
        let maxLabelWidth = layoutWidth - MessageViewModel.backgroundImageMargin.horizontal - contentMargin.horizontal
        let framesetter = CTFramesetterCreateWithAttributedString(str as CFAttributedString)
        let layoutSize = CGSize(width: maxLabelWidth, height: UILayoutFittingExpandedSize.height)
        textSize = ceil(CTFramesetterSuggestFrameSizeWithConstraints(framesetter, .zero, nil, layoutSize, nil))
        if textSize.height < minimumTextSize.height {
            textSize = minimumTextSize
        }
        let path = CGPath(rect: CGRect(origin: .zero, size: textSize), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, .zero, path, nil)
        lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, .zero, &origins)
        self.lineOrigins = origins.map{ CGPoint(x: ceil($0.x), y: ceil($0.y)) }
        // Make Links
        for link in links {
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
                let newPath = UIBezierPath(roundedRect: linkRect, cornerRadius: hightlightPathCornerRadius)
                if path != nil {
                    path!.append(newPath)
                } else {
                    path = newPath
                }
            }
            if let path = path {
                let links = linkRects.map {
                    Link(hitFrame: $0, backgroundPath: path, url: link.value.url)
                }
                self.links.append(contentsOf: links)
            }
        }
        // Calculate content size
        let time = message.createdAt.toUTCDate().timeHoursAndMinutes() as NSString
        let timeSize = time.size(withAttributes: [.font: DetailInfoMessageViewModel.timeFont])
        let hasStatusImage = style.contains(.sent)
        let statusImageWidth = hasStatusImage ? DetailInfoMessageViewModel.statusImageSize.width : 0
        let additionalTrailingSize = CGSize(width: timeLeftMargin + timeSize.width + statusImageWidth + DetailInfoMessageViewModel.statusLeftMargin, height: 16)
        var contentSize = textSize
        if let lastLine = lines.last {
            let rect = CTLineGetBoundsWithOptions(lastLine, [])
            let lastLineWithTrailingWidth = rect.width + additionalTrailingSize.width
            if lastLineWithTrailingWidth > maxLabelWidth {
                contentSize.height += additionalTrailingSize.height
            } else if lines.count == 1 {
                contentSize.width = lastLineWithTrailingWidth
            } else {
                contentSize.width = max(contentSize.width, lastLineWithTrailingWidth)
            }
        }
        if style.contains(.showFullname) {
            if message.userIsBot {
                let identityIconWidth = DetailInfoMessageViewModel.identityIconLeftMargin + DetailInfoMessageViewModel.identityIconSize.width
                contentSize.width = min(layoutSize.width, max(contentSize.width, fullnameWidth + identityIconWidth))
            } else {
                contentSize.width = min(layoutSize.width, max(contentSize.width, fullnameWidth))
            }
        }
        self.contentSize = contentSize
        didSetStyle()
    }
    
    override func didSetStyle() {
        let fullnameHeight = style.contains(.showFullname) ? fullnameFrame.height : 0
        let backgroundHeightAdjustment = style.contains(.showFullname) ? fullnameHeight + contentMargin.bottom : contentMargin.vertical
        if style.contains(.received) {
            backgroundImageFrame = CGRect(x: MessageViewModel.backgroundImageMargin.leading,
                                          y: 0,
                                          width: contentSize.width + contentMargin.horizontal,
                                          height: contentSize.height + backgroundHeightAdjustment)
            contentLabelFrame = CGRect(x: ceil(backgroundImageFrame.origin.x + contentMargin.leading),
                                       y: ceil(style.contains(.showFullname) ? fullnameHeight : contentMargin.top),
                                       width: textSize.width,
                                       height: textSize.height)
        } else if style.contains(.sent) {
            backgroundImageFrame = CGRect(x: layoutWidth - MessageViewModel.backgroundImageMargin.leading - contentMargin.horizontal - contentSize.width,
                                          y: 0,
                                          width: contentSize.width + contentMargin.horizontal,
                                          height: contentSize.height + backgroundHeightAdjustment)
            contentLabelFrame = CGRect(x: ceil(backgroundImageFrame.origin.x + contentMargin.trailing),
                                       y: ceil(contentMargin.top),
                                       width: textSize.width,
                                       height: textSize.height)
        }
        cellHeight = backgroundImageFrame.height + bottomSeparatorHeight
        super.didSetStyle()
    }
    
    func highlight(keyword: String) {
        let content = message.content as NSString
        var searchRange = NSRange(location: 0, length: content.length)
        var highlightRanges = [NSRange]()
        while searchRange.location < content.length {
            let foundRange = content.range(of: keyword, options: .caseInsensitive, range: searchRange)
            if foundRange.location != NSNotFound {
                highlightRanges.append(foundRange)
                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = content.length - searchRange.location
            } else {
                break
            }
        }
        assert(lines.count == lineOrigins.count)
        for (i, line) in lines.enumerated() {
            let lineOrigin = lineOrigins[i]
            for highlightRange in highlightRanges {
                guard let highlightRect = line.frame(forRange: highlightRange, lineOrigin: lineOrigin) else {
                    continue
                }
                let path = UIBezierPath(roundedRect: highlightRect, cornerRadius: hightlightPathCornerRadius)
                highlightPaths.append(path)
            }
        }
    }
    
    func removeHighlights() {
        highlightPaths = []
    }

}

fileprivate extension CTLine {
    
    func frame(forRange range: NSRange, lineOrigin: CGPoint) -> CGRect? {
        var highlightRect: CGRect?
        let runs = CTLineGetGlyphRuns(self) as! [CTRun]
        for run in runs {
            let cfRunRange = CTRunGetStringRange(run)
            let runRange = NSRange(cfRange: cfRunRange)
            if let intersection = runRange.intersection(range) {
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                let highlightRange = CFRange(location: intersection.location - runRange.location, length: intersection.length)
                let width = CGFloat(CTRunGetTypographicBounds(run, highlightRange, &ascent, &descent, &leading))
                let offsetX = CTLineGetOffsetForStringIndex(self, intersection.location, nil)
                let newRect = CGRect(x: lineOrigin.x + offsetX - leading,
                                     y: lineOrigin.y - descent,
                                     width: width + leading,
                                     height: ascent + descent)
                if let oldRect = highlightRect {
                    highlightRect = oldRect.union(newRect)
                } else {
                    highlightRect = newRect
                }
            }
        }
        return highlightRect
    }
    
}

fileprivate extension NSAttributedStringKey {
    static let ctFont = kCTFontAttributeName as NSAttributedStringKey
    static let ctForegroundColor = kCTForegroundColorAttributeName as NSAttributedStringKey
    static let ctParagraphStyle = kCTParagraphStyleAttributeName as NSAttributedStringKey
}

fileprivate extension CFRange {
    static let zero = CFRange(location: 0, length: 0)
    init(nsRange: NSRange) {
        self = CFRange(location: nsRange.location, length: nsRange.length)
    }
}

fileprivate extension NSRange {
    init(cfRange: CFRange) {
        self = NSRange(location: cfRange.location, length: cfRange.length)
    }
}

fileprivate extension NSMutableAttributedString {
    
    func setFont(_ font: CTFont) {
        let fullRange = NSRange(location: 0, length: length)
        removeAttribute(.ctFont, range: fullRange)
        let attr = [NSAttributedStringKey.ctFont: font]
        addAttributes(attr, range: fullRange)
    }
    
    func setColor(_ color: UIColor, for range: NSRange) {
        removeAttribute(.ctForegroundColor, range: range)
        let attr = [NSAttributedStringKey.ctForegroundColor: color.cgColor]
        addAttributes(attr, range: range)
    }
    
    func setColor(_ color: UIColor) {
        setColor(color, for: NSRange(location: 0, length: length))
    }
    
}
