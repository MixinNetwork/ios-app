import UIKit
import MixinServices

class PhotoMessageViewModel: PhotoRepresentableMessageViewModel, AttachmentLoadingViewModel {
    
    class var captionFont: UIFont {
        MessageFontSet.normalContent.scaled
    }
    
    class var captionTextColor: UIColor {
        return .chatText
    }
    
    var transcriptId: String?
    var isLoading = false
    var progress: Double?
    var downloadIsTriggeredByUser = false
    
    var shouldAutoDownload: Bool {
        switch AppGroupUserDefaults.User.autoDownloadPhotos {
        case .never:
            return false
        case .wifi:
            return ReachabilityManger.shared.isReachableOnEthernetOrWiFi
        case .wifiAndCellular:
            return true
        }
    }
    
    var automaticallyLoadsAttachment: Bool {
        return !shouldUpload && shouldAutoDownload
    }
    
    var showPlayIconOnMediaStatusDone: Bool {
        return false
    }
    
    var attachmentURL: URL? {
        if let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty {
            if let tid = transcriptId {
                return AttachmentContainer.url(transcriptId: tid, filename: mediaUrl)
            } else if !mediaUrl.hasPrefix("http") {
                return AttachmentContainer.url(for: .photos, filename: mediaUrl)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    private let linkColor = UIColor.systemTint
    private let highlightPathCornerRadius: CGFloat = 4
    private let additionalLineSpacing: CGFloat = 1
    private let trailingInfoLeftMargin: CGFloat = 20
    private let captionLeftPadding: CGFloat = 4
    
    var captionContent: CoreTextLabel.Content?
    var captionLabelFrame = CGRect.zero
    var highlightPaths = [UIBezierPath]()
    private var captionLinkRanges = [Link.Range]()
    private var presentedCaption = ""
    
    override var hasCaption: Bool {
        !(message.caption?.isEmpty ?? true)
    }
    
    override var statusNormalTintColor: UIColor {
        if hasCaption {
            return R.color.text_tertiary()!
        } else {
            return super.statusNormalTintColor
        }
    }
    
    override var trailingInfoColor: UIColor {
        if hasCaption {
            return R.color.text_quaternary()!
        } else {
            return super.trailingInfoColor
        }
    }
    
    var captionRawContent: String {
        message.mentionedFullnameReplacedCaption
    }
    
    var captionAttributedString: NSAttributedString {
        let str = NSMutableAttributedString(string: captionRawContent)
        str.setAttributes([.font: Self.captionFont, .foregroundColor: Self.captionTextColor],
                          range: NSRange(location: 0, length: str.length))
        for linkRange in captionLinkRanges {
            str.addAttribute(.link, value: linkRange.url, range: linkRange.range)
            str.addAttribute(.foregroundColor, value: linkColor, range: linkRange.range)
        }
        return NSAttributedString(attributedString: str)
    }
    
    override init(message: MessageItem) {
        super.init(message: message)
        updateOperationButtonStyle()
        layoutPosition = imageWithRatioMaybeAnArticle(contentRatio) ? .relativeOffset(0) : .center
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        guard hasCaption else {
            captionContent = nil
            captionLabelFrame = .zero
            highlightPaths = []
            return
        }
        captionLinkRanges = linkRanges(from: captionRawContent)
        let attributedString = self.captionAttributedString
        presentedCaption = attributedString.string
        
        let typesetWidth = Double(photoFrame.width - captionLeftPadding)
        let (lines, lineOrigins, lineRanges, textSize, lastLineWidth) = { () -> ([CTLine], [CGPoint], [CFRange], CGSize, CGFloat) in
            let cfStr = attributedString as CFAttributedString
            let typesetter = CTTypesetterCreateWithAttributedString(cfStr)
            
            var lines = [CTLine]()
            var lineOrigins = [CGPoint]()
            var lineRanges = [CFRange]()
            var characterIndex: CFIndex = 0
            var y: CGFloat = 0
            var lastLineWidth: CGFloat = 0
            var size = CGSize.zero
            var lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, characterIndex, typesetWidth)
            
            while lineCharacterCount > 0 {
                let isFirstLine = lines.isEmpty
                let lineRange = CFRange(location: characterIndex, length: lineCharacterCount)
                lineRanges.append(lineRange)
                
                let line = CTTypesetterCreateLine(typesetter, lineRange)
                lines.append(line)
                
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading) - CTLineGetTrailingWhitespaceWidth(line)))
                let lineHeight = max(Self.captionFont.lineHeight, ascent + descent + leading)
                
                size.height += lineHeight
                size.width = max(size.width, lineWidth)
                
                if isFirstLine {
                    y = max(4, descent)
                }
                y -= lineHeight
                if !isFirstLine {
                    y -= additionalLineSpacing
                }
                
                let lineOrigin = CGPoint(x: 0, y: y)
                lineOrigins.append(lineOrigin)
                
                lastLineWidth = lineWidth
                characterIndex += lineCharacterCount
                lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, characterIndex, typesetWidth)
            }
            
            size = CGSize(width: ceil(size.width),
                          height: ceil(size.height) + CGFloat(lines.count - 1) * additionalLineSpacing + 1)
            lineOrigins = lineOrigins.map {
                CGPoint(x: $0.x, y: $0.y + size.height)
            }
            
            return (lines, lineOrigins, lineRanges, size, lastLineWidth)
        }()
        
        var links = [Link]()
        for linkRange in captionLinkRanges {
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
                let newPath = UIBezierPath(roundedRect: linkRect, cornerRadius: highlightPathCornerRadius)
                if path != nil {
                    path!.append(newPath)
                } else {
                    path = newPath
                }
            }
            if let path = path {
                links += linkRects.map { Link(hitFrame: $0, backgroundPath: path, url: linkRange.url) }
            }
        }
        
        self.captionContent = CoreTextLabel.Content(lines: lines, lineOrigins: lineOrigins, links: links)
        
        let additionalTrailingSize: CGSize = {
            let statusImageWidth = showStatusImage ? StatusImage.size.width : 0
            let forwarderIconWidth = style.contains(.forwardedByBot) ? Self.forwarderIconRightMargin + R.image.conversation.ic_forwarder_bot()!.size.width : 0
            let encryptedIconWidth = isEncrypted ? Self.encryptedIconRightMargin + R.image.ic_message_encrypted()!.size.width : 0
            let pinIconWidth = isPinned ? Self.pinnedIconRightMargin + R.image.ic_message_pinned()!.size.width : 0
            let width = trailingInfoLeftMargin
                + forwarderIconWidth
                + encryptedIconWidth
                + pinIconWidth
                + timeFrame.width
                + statusImageWidth
                + DetailInfoMessageViewModel.statusLeftMargin
            return CGSize(width: width, height: 16)
        }()
        
        let captionTop = photoFrame.maxY + 6
        captionLabelFrame = CGRect(x: photoFrame.origin.x + captionLeftPadding, y: captionTop, width: photoFrame.width - captionLeftPadding, height: textSize.height)
        
        var backgroundHeight = captionLabelFrame.maxY - backgroundImageFrame.minY + 6
        let lastLineWithTrailingWidth = lastLineWidth + additionalTrailingSize.width
        if lastLineWithTrailingWidth > (photoFrame.width - captionLeftPadding) {
            backgroundHeight += additionalTrailingSize.height
        }
        backgroundImageFrame.size.height = backgroundHeight
        cellHeight = fullnameHeight + backgroundImageFrame.height + bottomSeparatorHeight
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
    }
    
    func highlight(keyword: String) {
        guard hasCaption, let captionContent = captionContent else {
            return
        }
        highlightPaths = []
        let presentedCaption = self.presentedCaption as NSString
        var searchRange = NSRange(location: 0, length: presentedCaption.length)
        var highlightRanges = [NSRange]()
        while searchRange.location < presentedCaption.length {
            let foundRange = presentedCaption.range(of: keyword, options: .caseInsensitive, range: searchRange)
            if foundRange.location != NSNotFound {
                highlightRanges.append(foundRange)
                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = presentedCaption.length - searchRange.location
            } else {
                break
            }
        }
        for (i, line) in captionContent.lines.enumerated() {
            let lineOrigin = captionContent.lineOrigins[i]
            for highlightRange in highlightRanges {
                guard let highlightRect = line.frame(forRange: highlightRange, lineOrigin: lineOrigin) else {
                    continue
                }
                let path = UIBezierPath(roundedRect: highlightRect, cornerRadius: highlightPathCornerRadius)
                highlightPaths.append(path)
            }
        }
    }
    
    func removeHighlights() {
        highlightPaths = []
    }
    
    func linkRanges(from string: String) -> [Link.Range] {
        var ranges = [Link.Range]()
        
        let nsString = string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        for mention in message.sortedMentions {
            var searchingRange = fullRange
            var range: NSRange
            while searchingRange.location < nsString.length {
                range = nsString.range(of: "\(Mention.prefix)\(mention.value)", range: searchingRange)
                guard range.location != NSNotFound else {
                    break
                }
                let newSearchingLocation = NSMaxRange(range)
                let newSearchingLength = searchingRange.length - (newSearchingLocation - searchingRange.location)
                searchingRange = NSRange(location: newSearchingLocation, length: newSearchingLength)
                guard !ranges.contains(where: { $0.range.intersection(range) != nil }) else {
                    continue
                }
                guard let url = MixinInternalURL.identityNumber(mention.key).url else {
                    continue
                }
                let linkRange = Link.Range(range: range, url: url)
                ranges.append(linkRange)
            }
        }
        
        Link.detector.enumerateMatches(in: string, options: [], using: { (result, _, _) in
            guard let result = result, let url = result.url else {
                return
            }
            guard !ranges.contains(where: { $0.range.intersection(result.range) != nil }) else {
                return
            }
            let range = Link.Range(range: result.range, url: url)
            ranges.append(range)
        })
        
        for (range, url) in AppIdentityNumberDetector.detect(in: string, range: fullRange) {
            guard !ranges.contains(where: { $0.range.intersection(range) != nil }) else {
                continue
            }
            let range = Link.Range(range: range, url: url)
            ranges.append(range)
        }
        
        Self.phoneNumberDetector?.enumerateMatches(in: string, options: [], range: fullRange) { result, _, _ in
            guard let range = result?.range else {
                return
            }
            guard range.location != NSNotFound else {
                return
            }
            guard !ranges.contains(where: { $0.range.intersection(range) != nil }) else {
                return
            }
            let rawNumber = nsString.substring(with: range)
            let utility = PhoneNumberValidator.global.utility
            guard let phoneNumber = try? utility.parse(rawNumber) else {
                return
            }
            let outputNumber: String
            if rawNumber.hasPrefix("+") {
                outputNumber = utility.format(phoneNumber, toType: .e164)
            } else {
                outputNumber = phoneNumber.adjustedNationalNumber()
            }
            guard let url = MixinInternalURL.phoneNumber(outputNumber).url else {
                return
            }
            let linkRange = Link.Range(range: range, url: url)
            ranges.append(linkRange)
        }
        return ranges
    }
    
    func beginAttachmentLoading(isTriggeredByUser: Bool) {
        downloadIsTriggeredByUser = isTriggeredByUser
        defer {
            updateOperationButtonStyle()
        }
        guard shouldBeginAttachmentLoading(isTriggeredByUser: isTriggeredByUser) else {
            return
        }
        updateMediaStatus(message: message, status: .PENDING)
        let message = Message.createMessage(message: self.message)
        if shouldUpload {
            if transcriptId != nil {
                assertionFailure()
            } else {
                let job = ImageUploadJob(message: message)
                UploaderQueue.shared.addJob(job: job)
            }
        } else {
            let job = AttachmentDownloadJob(transcriptId: transcriptId, messageId: message.messageId)
            ConcurrentJobQueue.shared.addJob(job: job)
        }
        isLoading = true
    }
    
    func cancelAttachmentLoading(isTriggeredByUser: Bool) {
        guard mediaStatus == MediaStatus.PENDING.rawValue else {
            return
        }
        guard isTriggeredByUser || (!downloadIsTriggeredByUser && !shouldUpload) else {
            return
        }
        if shouldUpload {
            if transcriptId != nil {
                assertionFailure()
            } else {
                let id = ImageUploadJob.jobId(messageId: message.messageId)
                UploaderQueue.shared.cancelJob(jobId: id)
            }
        } else {
            let id = AttachmentDownloadJob.jobId(transcriptId: transcriptId, messageId: message.messageId)
            ConcurrentJobQueue.shared.cancelJob(jobId: id)
        }
        if isTriggeredByUser {
            updateMediaStatus(message: message, status: .CANCELED)
        }
    }
    
}
