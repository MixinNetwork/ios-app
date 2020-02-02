import UIKit
import MixinServices

class AppButtonGroupViewModel: DetailInfoMessageViewModel {
    
    var frames = [CGRect]()
    var buttonGroupFrame = CGRect.zero
    
    private let margin = Margin(leading: 12, trailing: 12, top: 0, bottom: 0)
    
    override init(message: MessageItem) {
        super.init(message: message)
        backgroundImage = nil
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
        
        frames = []
        buttonGroupFrame = .zero
        
        let buttonLayoutWidth = width - margin.horizontal
        let buttonSizes: [CGSize] = message.appButtons?.map({
            AppButtonView.boundingSize(with: buttonLayoutWidth, title: $0.label)
        }) ?? []
        
        var bottomRight = CGPoint(x: margin.leading, y: 0)
        var y: CGFloat = style.contains(.fullname) ? fullnameFrame.height : 0
        var isFirstButton = true
        for buttonSize in buttonSizes {
            let origin: CGPoint
            if isFirstButton || bottomRight.x + buttonSize.width + margin.trailing <= width {
                origin = CGPoint(x: bottomRight.x, y: y)
            } else {
                origin = CGPoint(x: margin.leading, y: bottomRight.y)
                y = bottomRight.y
            }
            let frame = CGRect(origin: origin, size: buttonSize)
            frames.append(frame)
            bottomRight = CGPoint(x: frame.maxX, y: frame.maxY)
            isFirstButton = false
        }
        buttonGroupFrame = frames.reduce(.zero, { $0.union($1) })
        if let lastFrame = frames.last {
            cellHeight = lastFrame.maxY + AppButtonView.buttonMargin.bottom + margin.bottom
            if style.contains(.bottomSeparator) {
                cellHeight += bottomSeparatorHeight
            }
        } else {
            cellHeight = 1
        }
    }
    
}
