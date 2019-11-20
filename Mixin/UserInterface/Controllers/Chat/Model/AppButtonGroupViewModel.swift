import UIKit

class AppButtonGroupViewModel: DetailInfoMessageViewModel {
    
    private static let titleMargin = Margin(leading: 16, trailing: 16, top: 10, bottom: 12)
    
    var frames = [(button: CGRect, label: CGRect)]()
    var buttonGroupFrame = CGRect.zero
    
    private let margin = Margin(leading: 10, trailing: 10, top: 0, bottom: 0)
    
    private var buttonSizes = [CGSize]()
    
    override init(message: MessageItem) {
        super.init(message: message)
        backgroundImage = nil
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
        let boundingSize = CGSize(width: width - AppButtonGroupViewModel.titleMargin.horizontal - margin.horizontal,
                                  height: UIView.layoutFittingExpandedSize.height)
        let titleAttributes = [NSAttributedString.Key.font: MessageFontSet.appButtonTitle.scaled]
        buttonSizes = message.appButtons?.map({
            let titleSize = ($0.label as NSString).boundingRect(with: boundingSize,
                                                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                                attributes: titleAttributes,
                                                                context: nil)
            return CGSize(width: ceil(titleSize.width + AppButtonGroupViewModel.titleMargin.horizontal),
                          height: ceil(titleSize.height + AppButtonGroupViewModel.titleMargin.vertical))
        }) ?? []
        var bottomRight = CGPoint(x: margin.leading, y: 0)
        var y: CGFloat = 0
        var frames = [CGRect]()
        for buttonSize in buttonSizes {
            let frame: CGRect
            if bottomRight.x + buttonSize.width + margin.trailing <= width || abs(bottomRight.x - margin.leading) < 0.1 {
                frame = CGRect(x: bottomRight.x, y: y, width: buttonSize.width, height: buttonSize.height)
            } else {
                frame = CGRect(x: margin.leading, y: bottomRight.y, width: buttonSize.width, height: buttonSize.height)
                y = frame.origin.y
            }
            frames.append(frame)
            bottomRight = CGPoint(x: frame.maxX, y: frame.maxY)
        }
        let buttonMargin = AppButtonGroupViewModel.titleMargin
        self.frames = frames.map({
            let labelFrame = CGRect(x: $0.origin.x + buttonMargin.leading,
                                    y: $0.origin.y + buttonMargin.top,
                                    width: $0.width - buttonMargin.horizontal,
                                    height: $0.height - buttonMargin.vertical)
            return (button: $0, label: labelFrame)
        })
        if style.contains(.fullname) {
            self.frames = self.frames.map {
                (button: $0.button.offsetBy(dx: 0, dy: fullnameFrame.height),
                 label: $0.label.offsetBy(dx: 0, dy: fullnameFrame.height))
            }
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
