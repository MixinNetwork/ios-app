import UIKit

class AppCardMessageViewModel: CardMessageViewModel {

    static let titleAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)]
    static let descriptionAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]
    static let emptyLabelWidth: CGFloat = 2
    
    override class var bubbleImageProvider: BubbleImageProvider.Type {
        return AppCardBubbleImageProvider.self
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
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        let emptyLabelWidth = AppCardMessageViewModel.emptyLabelWidth
        let titleWidth = ceil(message.appCard?.title.size(withAttributes: AppCardMessageViewModel.titleAttributes).width ?? emptyLabelWidth)
        let descriptionWidth = ceil(message.appCard?.description.size(withAttributes: AppCardMessageViewModel.descriptionAttributes).width ?? emptyLabelWidth)
        contentWidth = max(emptyLabelWidth, titleWidth, descriptionWidth)
        super.init(message: message, style: style, fits: layoutWidth)
    }
    
}

extension AppCardMessageViewModel {
    
    class AppCardBubbleImageProvider: BubbleImageProvider {

        override class var leftTail: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_left")
        }
        
        override class var leftTailHighlight: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_left_highlight")
        }
        
    }
    
}
