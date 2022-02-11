import UIKit
import MixinServices

class StackedPhotoMessageViewModel: ImageMessageViewModel {
    
    override class var bubbleWidth: CGFloat {
        260 + 8
    }
        
    private(set) var photoMessageViewModels: [PhotoMessageViewModel] = []
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return StackedPhotoBubbleImageSet.self
    }
    
    override init(message: MessageItem) {
        super.init(message: message)
        if let items = message.messageItems, !items.isEmpty {
            photoMessageViewModels = items.compactMap({ messageItem -> PhotoMessageViewModel? in
                guard messageItem.category.hasSuffix("_IMAGE") else {
                    return nil
                }
                return PhotoMessageViewModel(message: messageItem)
            })
        }
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        let photoWidth: CGFloat
        if quotedMessageViewModel == nil {
            photoWidth = Self.bubbleWidth
        } else {
            photoWidth = Self.bubbleWidth - Self.quotingMessageMargin.horizontal
        }
        photoFrame.size = CGSize(width: photoWidth, height: 280)
        super.layout(width: width, style: style)
        if style.contains(.received) {
            photoFrame.origin.x += 8
        }
        if quotedMessageViewModel != nil {
            photoFrame.origin = .zero
        }
        layoutTrailingInfoBackgroundFrame()
    }
    
}
