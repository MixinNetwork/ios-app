import UIKit
import SwiftyMarkdown
import MixinServices

class PostMessageViewModel: TextMessageViewModel, BackgroundedTrailingInfoViewModel {
    
    private let numberOfMarkdownLines: Int = {
        switch ScreenWidth.current {
        case .short:
            return 5
        case .medium:
            return 8
        case .long:
            return 10
        }
    }()
    
    override var statusNormalTintColor: UIColor {
        .white
    }
    
    override var trailingInfoColor: UIColor {
        .white
    }
    
    override var maxNumberOfLines: Int? {
        10
    }
    
    override var contentAttributedString: NSAttributedString {
        let maxNumberOfLines = self.maxNumberOfLines ?? 10
        var lines = [String]()
        rawContent.enumerateLines { (line, stop) in
            lines.append(line)
            if lines.count == maxNumberOfLines {
                stop = true
            }
        }
        let string = lines.joined(separator: "\n")
        return NSAttributedString(string: string, attributes: [.font: Self.font])
    }
    
    var trailingInfoBackgroundFrame = CGRect.zero
    var html = ""
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        html = MarkdownConverter.htmlString(from: message.content ?? "", richFormat: false)
        layoutTrailingInfoBackgroundFrame()
    }
    
    override func linkRanges(from string: String) -> [Link.Range] {
        []
    }
    
}

extension PostMessageViewModel: SharedMediaItem {
    
    var messageId: String {
        message.messageId
    }
    
    var createdAt: String {
        message.createdAt
    }
    
}
