import UIKit
import SwiftyMarkdown
import MixinServices

class PostMessageViewModel: TextMessageViewModel, BackgroundedTrailingInfoViewModel {
    
    override var statusNormalTintColor: UIColor {
        .white
    }
    
    override var maxContentWidth: CGFloat {
        performSynchronouslyOnMainThread {
            AppDelegate.current.window.bounds.width / 3 * 2
        }
    }
    
    override var maxNumberOfLines: Int? {
        20
    }
    
    override var contentAttributedString: NSAttributedString {
        let md = SwiftyMarkdown(string: rawContent)
        md.link.color = .theme
        return md.attributedString()
    }
    
    var trailingInfoBackgroundFrame = CGRect.zero
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        layoutTrailingInfoBackgroundFrame()
    }
    
    override func linkRanges(from string: String) -> [Link.Range] {
        []
    }
    
}
