import UIKit

class AppButtonGroupViewModel: DetailInfoMessageViewModel {
    
    static let titleFont = UIFont.boldSystemFont(ofSize: 16)
    
    private static let titleMargin = Margin(leading: 16, trailing: 16, top: 10, bottom: 12)
    private static let titleAttribute = [NSAttributedStringKey.font: AppButtonGroupViewModel.titleFont]
    
    var frames = [(button: CGRect, label: CGRect)]()
    
    private let buttonSizes: [CGSize]
    private let margin = Margin(leading: 10, trailing: 10, top: 0, bottom: 0)
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        let boundingSize = CGSize(width: layoutWidth - AppButtonGroupViewModel.titleMargin.horizontal - margin.horizontal,
                                  height: UILayoutFittingExpandedSize.height)
        buttonSizes = message.appButtons?.map({
            let titleSize = ($0.label as NSString).boundingRect(with: boundingSize,
                                                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                                attributes: AppButtonGroupViewModel.titleAttribute,
                                                                context: nil)
            return CGSize(width: ceil(titleSize.width + AppButtonGroupViewModel.titleMargin.horizontal),
                          height: ceil(titleSize.height + AppButtonGroupViewModel.titleMargin.vertical))
        }) ?? []
        super.init(message: message, style: style, fits: layoutWidth)
        backgroundImage = nil
    }
    
    override func didSetStyle() {
        super.didSetStyle()
        var bottomRight = CGPoint(x: margin.leading, y: 0)
        var y: CGFloat = 0
        var frames = [CGRect]()
        for buttonSize in buttonSizes {
            let frame: CGRect
            if bottomRight.x + buttonSize.width + margin.trailing <= layoutWidth || abs(bottomRight.x - margin.leading) < 0.1 {
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
