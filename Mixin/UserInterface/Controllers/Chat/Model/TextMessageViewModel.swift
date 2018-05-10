import UIKit

class TextMessageViewModel: DetailInfoMessageViewModel {
    
    private(set) var content: CoreTextLabel.Content?
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
        let text = message.content
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        // Detect links
        var linksMap = [NSRange: URL]()
        if let fixedLinks = fixedLinks {
            linksMap = fixedLinks
        } else if let matches = Link.detector?.matches(in: text, options: [], range: fullRange) {
            for match in matches {
                linksMap[match.range] = match.url
            }
        }
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
        for range in linksMap.keys {
            str.setCTForegroundColor(linkColor, for: range)
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
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, .zero, &origins)
        let lineOrigins = origins.map{ CGPoint(x: ceil($0.x), y: ceil($0.y)) }
        // Make Links
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
                let newPath = UIBezierPath(roundedRect: linkRect, cornerRadius: hightlightPathCornerRadius)
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
        // Make content
        content = CoreTextLabel.Content(lines: lines, lineOrigins: lineOrigins, links: links)
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
        guard let content = content else {
            return
        }
        let messageContent = message.content as NSString
        var searchRange = NSRange(location: 0, length: messageContent.length)
        var highlightRanges = [NSRange]()
        while searchRange.location < messageContent.length {
            let foundRange = messageContent.range(of: keyword, options: .caseInsensitive, range: searchRange)
            if foundRange.location != NSNotFound {
                highlightRanges.append(foundRange)
                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = messageContent.length - searchRange.location
            } else {
                break
            }
        }
        assert(content.lines.count == content.lineOrigins.count)
        for (i, line) in content.lines.enumerated() {
            let lineOrigin = content.lineOrigins[i]
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
