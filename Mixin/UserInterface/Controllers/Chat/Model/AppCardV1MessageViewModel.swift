import Foundation
import MixinServices

final class AppCardV1MessageViewModel: DetailInfoMessageViewModel {
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        LightRightBubbleImageSet.self
    }
    
    let coverRatio: CGFloat = 16.0 / 10.0
    let coverBottomSpacing: CGFloat = 10
    let otherSpacing: CGFloat = 8
    let bottomSpacing: CGFloat = 12
    let labelLayoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    let buttonsLeadingMargin: CGFloat = 4
    let buttonsTrailingMargin: CGFloat = 0
    
    let titleFont: UIFont = .scaledFont(ofSize: 16, weight: .medium)
    let descriptionFont: UIFont = .systemFont(ofSize: 14)
    
    let content: AppCardData.V1Content
    let buttonsViewModel = AppButtonGroupViewModel()
    
    private(set) var leadingConstant: CGFloat = 0
    private(set) var trailingConstant: CGFloat = 0
    private(set) var previewFrame: CGRect = .zero
    
    init(message: MessageItem, content: AppCardData.V1Content) {
        self.content = content
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: Style) {
        super.layout(width: width, style: style)
        if style.contains(.received) {
            leadingConstant = 9
            trailingConstant = -2
        } else {
            leadingConstant = 2
            trailingConstant = -9
        }
        super.layout(width: width, style: style)
        
        let contentWidth: CGFloat = min(340, max(240, round(width * 3 / 4)))
        let labelFittingSize = CGSize(width: contentWidth - leadingConstant + trailingConstant - labelLayoutMargins.horizontal,
                                      height: UIView.layoutFittingExpandedSize.height)
        let coverImageHeight: CGFloat = if content.coverURL == nil {
            otherSpacing
        } else {
            (contentWidth + leadingConstant - trailingConstant) / coverRatio + coverBottomSpacing
        }
        let titleHeight: CGFloat = {
            if content.title.isEmpty {
                return 0
            } else {
                let rect = (content.title as NSString).boundingRect(
                    with: labelFittingSize,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: titleFont],
                    context: nil
                )
                return rect.height + otherSpacing
            }
        }()
        let descriptionHeight: CGFloat = {
            if content.description.isEmpty {
                return -otherSpacing
            } else {
                let rect = (content.description as NSString).boundingRect(
                    with: labelFittingSize,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: UIFontMetrics.default.scaledFont(for: descriptionFont)],
                    context: nil
                )
                return rect.height
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
        
        buttonsViewModel.layout(lineWidth: contentWidth - buttonsLeadingMargin - buttonsTrailingMargin,
                                contents: content.actions.map(\.label))
        cellHeight = fullnameHeight
            + backgroundImageFrame.height
            + buttonsViewModel.buttonGroupFrame.height
            + timeFrame.height
            + timeMargin.bottom
            + bottomSeparatorHeight
        layoutDetailInfo(insideBackgroundImage: true, backgroundImageFrame: backgroundImageFrame)
        layoutQuotedMessageIfPresent()
        if !style.contains(.received) {
            timeFrame.origin.x += statusFrame.width
        }
        previewFrame = {
            var buttonsFrame = buttonsViewModel.buttonGroupFrame
            buttonsFrame.origin.y = backgroundImageFrame.maxY
            return backgroundImageFrame.union(buttonsFrame)
        }()
    }
    
}
