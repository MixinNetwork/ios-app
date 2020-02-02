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
        var lines = [String]()
        rawContent.enumerateLines { (line, stop) in
            lines.append(line)
            if lines.count == 20 {
                stop = true
            }
        }
        let string = lines.joined(separator: "\n")
        let md = SwiftyMarkdown(string: string)
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
