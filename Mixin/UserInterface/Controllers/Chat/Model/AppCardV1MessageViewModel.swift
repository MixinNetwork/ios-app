import Foundation
import MixinServices

class AppCardV1MessageViewModel: DetailInfoMessageViewModel {
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        LightRightBubbleImageSet.self
    }
    
    static let coverBottomSpacing: CGFloat = 10
    static let otherSpacing: CGFloat = 8
    static let labelLayoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    static let descriptionLineSpacing: CGFloat = 3
    
    let bottomSpacing: CGFloat = 12
    let buttonsLeadingMargin: CGFloat = 4
    let buttonsTrailingMargin: CGFloat = 0
    
    let content: AppCardData.V1Content
    let buttonsViewModel = AppButtonGroupViewModel()
    
    private(set) var leadingConstant: CGFloat = 0
    private(set) var trailingConstant: CGFloat = 0
    private(set) var previewFrame: CGRect = .zero
    
    init(message: MessageItem, content: AppCardData.V1Content) {
        self.content = content
        super.init(message: message)
        self.thumbnail = content.cover?.thumbnail()
    }
    
    override func layout(width: CGFloat, style: Style) {
        if style.contains(.received) {
            leadingConstant = 9
            trailingConstant = -2
        } else {
            leadingConstant = 2
            trailingConstant = -9
        }
        super.layout(width: width, style: style)
        
        let contentWidth: CGFloat = min(340, max(240, round(width * 3 / 4)))
        let labelFittingSize = CGSize(width: contentWidth - leadingConstant + trailingConstant - Self.labelLayoutMargins.horizontal,
                                      height: UIView.layoutFittingExpandedSize.height)
        let coverImageHeight: CGFloat
        if let cover = content.cover {
            coverImageHeight = (contentWidth + leadingConstant - trailingConstant) / cover.ratio + Self.coverBottomSpacing
        } else {
            coverImageHeight = Self.otherSpacing
        }
        let titleHeight: CGFloat = {
            if let title = content.title, !title.isEmpty {
                let rect = (title as NSString).boundingRect(
                    with: labelFittingSize,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: MessageFontSet.appCardV1Title.scaled],
                    context: nil
                )
                return rect.height + Self.otherSpacing
            } else {
                return 0
            }
        }()
        let descriptionHeight: CGFloat = {
            if let description = content.description, !description.isEmpty {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = Self.descriptionLineSpacing
                let rect = (description as NSString).boundingRect(
                    with: labelFittingSize,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [
                        .font: MessageFontSet.cardSubtitle.scaled,
                        .paragraphStyle: paragraphStyle,
                    ],
                    context: nil
                )
                return rect.height
            } else {
                return -Self.otherSpacing
            }
        }()
        let contentHeight: CGFloat = coverImageHeight + titleHeight + descriptionHeight + bottomSpacing
        let fullnameHeight: CGFloat = style.contains(.fullname) ? fullnameFrame.height : 0
        let x: CGFloat
        if style.contains(.received) {
            x = Self.bubbleMargin.leading
        } else {
            x = width - Self.bubbleMargin.leading - contentWidth
        }
        backgroundImageFrame = CGRect(x: x, y: fullnameHeight, width: contentWidth, height: contentHeight)
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
        layoutQuotedMessageIfPresent()
        
        buttonsViewModel.layout(lineWidth: contentWidth - buttonsLeadingMargin - buttonsTrailingMargin,
                                contents: content.actions.map(\.label))
        cellHeight = fullnameHeight
            + backgroundImageFrame.height
            + buttonsViewModel.buttonGroupFrame.height
            + timeFrame.height
            + timeMargin.bottom
            + bottomSeparatorHeight
        previewFrame = {
            var buttonsFrame = buttonsViewModel.buttonGroupFrame
            buttonsFrame.origin = CGPoint(x: backgroundImageFrame.origin.x, y: backgroundImageFrame.maxY)
            return backgroundImageFrame.union(buttonsFrame)
        }()
    }
    
}
