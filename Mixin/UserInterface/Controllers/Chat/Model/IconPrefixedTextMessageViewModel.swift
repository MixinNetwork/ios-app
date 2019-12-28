import UIKit

class IconPrefixedTextMessageViewModel: TextMessageViewModel {
    
    var prefixFrame = CGRect.zero
    var prefixImage: UIImage?
    
    private let prefixSize = CGSize(width: 14, height: 14)
    private let prefixInset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 6)
    
    override var contentAdditionalLeadingMargin: CGFloat {
        return prefixSize.width + prefixInset.horizontal
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        prefixFrame = CGRect(x: contentLabelFrame.origin.x + prefixInset.left,
                             y: contentLabelFrame.origin.y,
                             width: prefixSize.width,
                             height: contentLabelFrame.height)
        contentLabelFrame.origin.x += (prefixFrame.width + prefixInset.horizontal)
    }
    
}
