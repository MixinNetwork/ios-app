import UIKit

class AppButtonGroupViewModel: DetailInfoMessageViewModel {
    
    private static let titleMargin = Margin(leading: 16, trailing: 16, top: 10, bottom: 12)
    private static let buttonMargin = Margin(leading: 5, trailing: 5, top: 1, bottom: 3)
    
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
        
        let boundingSize = CGSize(width: width - Self.buttonMargin.horizontal - Self.titleMargin.horizontal - margin.horizontal,
                                  height: UIView.layoutFittingExpandedSize.height)
        let titleAttributes = [NSAttributedString.Key.font: MessageFontSet.appButtonTitle.scaled]
        let buttonSizes: [CGSize] = message.appButtons?.map({
            let titleSize = ($0.label as NSString).boundingRect(with: boundingSize,
                                                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                                attributes: titleAttributes,
                                                                context: nil)
            return CGSize(width: ceil(titleSize.width + Self.titleMargin.horizontal),
                          height: ceil(titleSize.height + Self.titleMargin.vertical))
        }) ?? []
        
        var bottomRight = CGPoint(x: margin.leading, y: 0)
        var y: CGFloat = style.contains(.fullname) ? fullnameFrame.height : 0
        for buttonSize in buttonSizes {
            let frame: CGRect
            let isFirstButtonOfTheLine = abs(bottomRight.x - margin.leading) < 1
            if bottomRight.x + buttonSize.width + Self.buttonMargin.horizontal + margin.trailing <= width || isFirstButtonOfTheLine {
                let leadingMargin = isFirstButtonOfTheLine ? Self.buttonMargin.leading : Self.buttonMargin.horizontal
                frame = CGRect(x: bottomRight.x + leadingMargin,
                               y: y + Self.buttonMargin.top,
                               width: buttonSize.width,
                               height: buttonSize.height)
            } else {
                frame = CGRect(x: margin.leading + Self.buttonMargin.leading,
                               y: bottomRight.y + Self.buttonMargin.vertical,
                               width: buttonSize.width,
                               height: buttonSize.height)
                y = bottomRight.y + Self.buttonMargin.bottom
            }
            frames.append(frame)
            bottomRight = CGPoint(x: frame.maxX, y: frame.maxY)
        }
        buttonGroupFrame = frames.reduce(.zero, { $0.union($1) })
        if let lastFrame = frames.last {
            cellHeight = lastFrame.maxY + margin.bottom
            if style.contains(.fullname) {
                cellHeight += fullnameFrame.height
            }
            if style.contains(.bottomSeparator) {
                cellHeight += bottomSeparatorHeight
            }
        } else {
            cellHeight = 1
        }
    }
    
}
