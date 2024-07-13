import UIKit
import MixinServices

final class AppButtonGroupMessageViewModel: DetailInfoMessageViewModel {
    
    let buttonsViewModel = AppButtonGroupViewModel()
    
    var contentFrame: CGRect {
        var frame = buttonsViewModel.buttonGroupFrame
        frame.origin.x = margin.leading
        return frame
    }
    
    private let margin = Margin(leading: 12, trailing: 12, top: 0, bottom: 0)
    
    override init(message: MessageItem) {
        super.init(message: message)
        backgroundImage = nil
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
        
        let contents = message.appButtons?.map(\.label) ?? []
        buttonsViewModel.layout(lineWidth: maxContentWidth + margin.horizontal, contents: contents)
        
        if let lastFrame = buttonsViewModel.frames.last {
            cellHeight = lastFrame.maxY + margin.vertical
            if style.contains(.bottomSeparator) {
                cellHeight += bottomSeparatorHeight
            }
        } else {
            cellHeight = 1
        }
    }
    
}
