import UIKit

class AppCardMessageViewModel: CardMessageViewModel {
    
    static let emptyLabelWidth: CGFloat = 2
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return AppCardBubbleImageSet.self
    }
    
    override var leftLeadingMargin: CGFloat {
        return 18
    }
    
    override var leftTrailingMargin: CGFloat {
        return 12
    }
    
    override var size: CGSize {
        // 48 is iconImageView.width, 10 is the spacing between icon and title
        return CGSize(width: contentWidth + leftLeadingMargin + leftTrailingMargin + 48 + 10, height: 72)
    }
    
    private var contentWidth: CGFloat = 0
    
    override init(message: MessageItem) {
        let emptyLabelWidth = AppCardMessageViewModel.emptyLabelWidth
        let titleAttributes = [NSAttributedString.Key.font: MessageFontSet.appCardTitle.font]
        let titleWidth = ceil(message.appCard?.title.size(withAttributes: titleAttributes).width ?? emptyLabelWidth)
        let descriptionAttributes = [NSAttributedString.Key.font: MessageFontSet.appCardDescription.font]
        let descriptionWidth = ceil(message.appCard?.description.size(withAttributes: descriptionAttributes).width ?? emptyLabelWidth)
        contentWidth = max(emptyLabelWidth, titleWidth, descriptionWidth)
        super.init(message: message)
    }
    
}
