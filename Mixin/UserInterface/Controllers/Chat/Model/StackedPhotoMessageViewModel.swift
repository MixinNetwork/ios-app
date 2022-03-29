import UIKit
import MixinServices

class StackedPhotoMessageViewModel: ImageMessageViewModel {
    
    private let stackedPhotoViewHeight: CGFloat = 280
    
    override class var bubbleWidth: CGFloat {
        258
    }
        
    private(set) var photoMessageViewModels: [PhotoMessageViewModel] = []
    private(set) var stackedPhotoViewFrame = CGRect.zero
    
    override init(message: MessageItem) {
        super.init(message: message)
        if let items = message.messageItems, !items.isEmpty {
            photoMessageViewModels = items.map({ PhotoMessageViewModel(message: $0) })
        }
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        photoFrame.size = CGSize(width: Self.bubbleWidth, height: stackedPhotoViewHeight + 3)
        super.layout(width: width, style: style)
        if style.contains(.received) {
            photoFrame.origin.x += 8
        }
        stackedPhotoViewFrame = CGRect(x: photoFrame.origin.x,
                                       y: photoFrame.origin.y + 1,
                                       width: photoFrame.width,
                                       height: stackedPhotoViewHeight - 1)
        layoutTrailingInfoBackgroundFrame()
    }
    
}
