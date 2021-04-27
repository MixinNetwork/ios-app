import UIKit
import MixinServices

class PostMessageViewModel: DetailInfoMessageViewModel, BackgroundedTrailingInfoViewModel {
    
    override var statusNormalTintColor: UIColor {
        .white
    }
    
    override var trailingInfoColor: UIColor {
        .white
    }
    
    let html: String // For display
    let contentAttributedString: NSAttributedString // For estimating cell frame
    
    var webViewFrame: CGRect = .zero
    var trailingInfoBackgroundFrame: CGRect = .zero
    
    private let minTextHeight: CGFloat = 40
    private let webViewLeadingMargin: CGFloat = 4
    private let webViewTrailingMargin: CGFloat = 3
    private let frameEstimatingMaxCharacterCount: UInt = 120
    private let frameEstimationMaxLineCount: UInt = {
        switch ScreenHeight.current {
        case .short, .medium:
            return 4
        case .long:
            return 5
        case .extraLong:
            return 6
        }
    }()
    
    override init(message: MessageItem) {
        let previewableMarkdown: String = {
            var lines = [String]()
            (message.content ?? "").enumerateLines { (line, stop) in
                lines.append(line)
                if lines.count == 30 {
                    stop = true
                }
            }
            return lines.joined(separator: "\n")
        }()
        html = MarkdownConverter.htmlString(from: previewableMarkdown, richFormat: false)
        contentAttributedString = MarkdownConverter.attributedString(from: previewableMarkdown,
                                                                     maxNumberOfCharacters: frameEstimatingMaxCharacterCount,
                                                                     maxNumberOfLines: frameEstimationMaxLineCount)
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        let backgroundWidth = layoutWidth - DetailInfoMessageViewModel.bubbleMargin.horizontal
        let widthToFit = round(backgroundWidth - contentMargin.horizontal - webViewLeadingMargin - webViewTrailingMargin)
        let sizeToFit = CGSize(width: widthToFit, height: UIView.layoutFittingExpandedSize.height)
        let textSize = contentAttributedString.boundingRect(with: sizeToFit,
                                                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                            context: nil)
        let height = ceil(max(minTextHeight, textSize.height))
        let bubbleMargin = DetailInfoMessageViewModel.bubbleMargin
        let contentLabelTopMargin: CGFloat = {
            if style.contains(.fullname) {
                return fullnameFrame.height
            } else {
                return contentMargin.top
            }
        }()
        if style.contains(.received) {
            backgroundImageFrame = CGRect(x: bubbleMargin.leading,
                                          y: 0,
                                          width: backgroundWidth,
                                          height: height + contentLabelTopMargin + contentMargin.bottom)
            webViewFrame = CGRect(x: ceil(backgroundImageFrame.origin.x + contentMargin.leading) + webViewLeadingMargin,
                                  y: contentLabelTopMargin,
                                  width: sizeToFit.width,
                                  height: height)
        } else {
            backgroundImageFrame = CGRect(x: width - bubbleMargin.leading - backgroundWidth,
                                          y: 0,
                                          width: backgroundWidth,
                                          height: height + contentLabelTopMargin + contentMargin.bottom)
            webViewFrame = CGRect(x: ceil(backgroundImageFrame.origin.x + contentMargin.trailing + webViewTrailingMargin),
                                  y: contentLabelTopMargin,
                                  width: sizeToFit.width,
                                  height: height)
        }
        cellHeight = backgroundImageFrame.height + bottomSeparatorHeight
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
        if quotedMessageViewModel != nil && style.contains(.fullname) {
            backgroundImageFrame.origin.y += fullnameFrame.height
            backgroundImageFrame.size.height -= fullnameFrame.height
        }
        layoutTrailingInfoBackgroundFrame()
    }
    
}

extension PostMessageViewModel: SharedMediaItem {
    
    var messageId: String {
        message.messageId
    }
    
    var createdAt: String {
        message.createdAt
    }
    
}
