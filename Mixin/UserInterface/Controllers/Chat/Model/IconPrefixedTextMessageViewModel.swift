import UIKit

class IconPrefixedTextMessageViewModel: TextMessageViewModel {
    
    static let prefixSize = CGSize(width: 14, height: 14)
    static let prefixInset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 6)
    
    var prefixFrame = CGRect.zero
    var prefixImage: UIImage?
    
    override var contentAdditionalLeadingMargin: CGFloat {
        return IconPrefixedTextMessageViewModel.prefixSize.width
            + IconPrefixedTextMessageViewModel.prefixInset.horizontal
    }
    
    override func didSetStyle() {
        super.didSetStyle()
        prefixFrame = CGRect(x: contentLabelFrame.origin.x + IconPrefixedTextMessageViewModel.prefixInset.left,
                             y: contentLabelFrame.origin.y,
                             width: IconPrefixedTextMessageViewModel.prefixSize.width,
                             height: contentLabelFrame.height)
        contentLabelFrame.origin.x += (prefixFrame.width + IconPrefixedTextMessageViewModel.prefixInset.horizontal)
    }
    
}
