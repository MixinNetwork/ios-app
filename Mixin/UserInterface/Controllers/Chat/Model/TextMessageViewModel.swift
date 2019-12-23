import UIKit
import MixinServices

class TextMessageViewModel: DetailInfoMessageViewModel {
    
    class var ctFont: CTFont {
        return CoreTextFontSet.textMessage.ctFont
    }
    
    class var lineHeight: CGFloat {
        return CoreTextFontSet.textMessage.lineHeight
    }
    
    class var textColor: UIColor {
        return .chatText
    }
    
    var content: CoreTextLabel.Content?
    var contentLabelFrame = CGRect.zero
    var highlightPaths = [UIBezierPath]()
    
    private let timeLeftMargin: CGFloat = 20
    private let minimumTextSize = CGSize(width: 5, height: 17)
    private let linkColor = UIColor.systemTint
    private let hightlightPathCornerRadius: CGFloat = 4
    
    private var contentSize = CGSize.zero // contentSize is textSize concatenated with additionalTrailingSize and fullname width
    private var linkRanges = [Link.Range]()
    
    override var debugDescription: String {
        return super.debugDescription + ", contentSize: \(contentSize), contentLength: \(message.content.count)"
    }
    
    var fullnameHeight: CGFloat {
        return style.contains(.fullname) ? fullnameFrame.height : 0
    }

    var backgroundWidth: CGFloat {
        return contentAdditionalLeadingMargin + contentSize.width + contentMargin.horizontal
    }
    
    var contentLabelTopMargin: CGFloat {
        return style.contains(.fullname) ? fullnameHeight : contentMargin.top
    }
    
    var contentAdditionalLeadingMargin: CGFloat {
        return 0
    }
    
    var rawContent: String {
        return message.content
    }
    
    override init(message: MessageItem) {
        super.init(message: message)
        linkRanges = self.linkRanges(from: rawContent)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        let str = NSMutableAttributedString(string: rawContent)
        let cfStr = str as CFMutableAttributedString
        // Set attributes
        setDefaultAttributes(on: cfStr)
        for linkRange in linkRanges {
            let range = CFRange(nsRange: linkRange.range)
            CFAttributedStringSetAttribute(cfStr, range, kCTForegroundColorAttributeName, linkColor)
        }
        // Make CTLine and Origins
        var (lines, lineOrigins, lineRanges, textSize, lastLineWidth) = typeset(attributedString: cfStr)
        if textSize.height < minimumTextSize.height {
            textSize = minimumTextSize
        }
        // Make Links
        var links = [Link]()
        for linkRange in linkRanges {
            let linkRects: [CGRect] = lines.enumerated().compactMap({ (index, line) -> CGRect? in
                let lineOrigin = lineOrigins[index]
                let lineRange = NSRange(cfRange: lineRanges[index])
                if let intersection = lineRange.intersection(linkRange.range) {
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
                links += linkRects.map{ Link(hitFrame: $0, backgroundPath: path, url: linkRange.url) }
            }
        }
        // Make content
        self.content = CoreTextLabel.Content(lines: lines, lineOrigins: lineOrigins, links: links)
        // Calculate content size
        let additionalTrailingSize: CGSize = {
            let statusImageWidth = showStatusImage
                ? ImageSet.MessageStatus.size.width
                : 0
            let width = timeLeftMargin
                + timeFrame.width
                + statusImageWidth
                + DetailInfoMessageViewModel.statusLeftMargin
            return CGSize(width: width, height: 16)
        }()
        
        var contentSize = textSize
        let lastLineWithTrailingWidth = lastLineWidth + additionalTrailingSize.width
        if lastLineWithTrailingWidth > maxContentWidth {
            contentSize.height += additionalTrailingSize.height
        } else if lines.count == 1 {
            contentSize.width = lastLineWithTrailingWidth
        } else {
            contentSize.width = max(contentSize.width, lastLineWithTrailingWidth)
        }
        if style.contains(.fullname) {
            if message.userIsBot {
                let identityIconWidth = DetailInfoMessageViewModel.identityIconLeftMargin
                    + DetailInfoMessageViewModel.identityIconSize.width
                contentSize.width = min(maxContentWidth, max(contentSize.width, fullnameFrame.size.width + identityIconWidth))
            } else {
                contentSize.width = min(maxContentWidth, max(contentSize.width, fullnameFrame.size.width))
            }
        }
        self.contentSize = contentSize
        let bubbleMargin = DetailInfoMessageViewModel.bubbleMargin
        if style.contains(.received) {
            backgroundImageFrame = CGRect(x: bubbleMargin.leading,
                                          y: 0,
                                          width: backgroundWidth,
                                          height: contentSize.height + contentLabelTopMargin + contentMargin.bottom)
            contentLabelFrame = CGRect(x: ceil(backgroundImageFrame.origin.x + contentMargin.leading),
                                       y: contentLabelTopMargin,
                                       width: textSize.width,
                                       height: textSize.height)
        } else {
            backgroundImageFrame = CGRect(x: width - bubbleMargin.leading - backgroundWidth,
                                          y: 0,
                                          width: backgroundWidth,
                                          height: contentSize.height + contentLabelTopMargin + contentMargin.bottom)
            contentLabelFrame = CGRect(x: ceil(backgroundImageFrame.origin.x + contentMargin.trailing),
                                       y: contentLabelTopMargin,
                                       width: textSize.width,
                                       height: textSize.height)
        }
        cellHeight = backgroundImageFrame.height + bottomSeparatorHeight
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
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
    
    func linkRanges(from string: String) -> [Link.Range] {
        var map = [Link.Range]()
        Link.detector.enumerateMatches(in: string, options: [], using: { (result, _, _) in
            guard let result = result, let url = result.url else {
                return
            }
            let range = Link.Range(range: result.range, url: url)
            map.append(range)
        })
        return map
    }
    
    func setDefaultAttributes(on string: CFMutableAttributedString) {
        let fullRange = CFRange(location: 0, length: CFAttributedStringGetLength(string))
        CFAttributedStringSetAttribute(string, fullRange, kCTFontAttributeName, type(of: self).ctFont)
        CFAttributedStringSetAttribute(string, fullRange, kCTForegroundColorAttributeName, type(of: self).textColor)
    }
    
    typealias TypesetResult = (lines: [CTLine], lineOrigins: [CGPoint], lineRanges: [CFRange], size: CGSize, lastLineWidth: CGFloat)
    func typeset(attributedString: CFAttributedString) -> TypesetResult {
        let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        
        var lines = [CTLine]()
        var lineOrigins = [CGPoint]()
        var lineRanges = [CFRange]()
        var characterIndex: CFIndex = 0
        var y: CGFloat = 4
        var lastLineWidth: CGFloat = 0
        var size = CGSize.zero
        
        while true {
            let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, characterIndex, Double(maxContentWidth))
            if lineCharacterCount > 0 {
                let lineRange = CFRange(location: characterIndex, length: lineCharacterCount)
                let line = CTTypesetterCreateLine(typesetter, lineRange)
                let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(line)))
                let lineOrigin = CGPoint(x: 0, y: y)
                lines.append(line)
                lineOrigins.append(lineOrigin)
                lineRanges.append(lineRange)
                size.height += type(of: self).lineHeight
                size.width = max(size.width, lineWidth)
                y += type(of: self).lineHeight
                lastLineWidth = lineWidth
                characterIndex += lineCharacterCount
            } else {
                break
            }
        }
        
        return (lines, lineOrigins.reversed(), lineRanges, size, lastLineWidth)
    }
    
}
