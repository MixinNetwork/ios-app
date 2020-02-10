import UIKit
import MixinServices

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
    
    override var contentWidth: CGFloat {
        // 48 is iconImageView.width, 10 is the spacing between icon and title
        labelWidth + leftLeadingMargin + leftTrailingMargin + 48 + 10
    }
    
    private var labelWidth: CGFloat = 0
    
    override init(message: MessageItem) {
        let emptyLabelWidth = AppCardMessageViewModel.emptyLabelWidth
        let titleAttributes = [NSAttributedString.Key.font: MessageFontSet.appCardTitle.scaled]
        let titleWidth = ceil(message.appCard?.title.size(withAttributes: titleAttributes).width ?? emptyLabelWidth)
        let descriptionAttributes = [NSAttributedString.Key.font: MessageFontSet.appCardDescription.scaled]
        let descriptionWidth = ceil(message.appCard?.description.size(withAttributes: descriptionAttributes).width ?? emptyLabelWidth)
        labelWidth = max(emptyLabelWidth, titleWidth, descriptionWidth)
        super.init(message: message)
    }
    
}
