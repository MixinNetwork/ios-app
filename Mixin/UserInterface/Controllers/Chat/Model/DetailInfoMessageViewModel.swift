import UIKit

class DetailInfoMessageViewModel: MessageViewModel {
    
    static let pendingImage = #imageLiteral(resourceName: "ic_chat_time").withRenderingMode(.alwaysTemplate)
    static let checkmarkImage = #imageLiteral(resourceName: "ic_chat_checkmark").withRenderingMode(.alwaysTemplate)
    static let doubleCheckmarkImage = #imageLiteral(resourceName: "ic_chat_double_checkmark").withRenderingMode(.alwaysTemplate)
    static let statusImageSize = CGSize(width: #imageLiteral(resourceName: "ic_chat_double_checkmark").size.width, height: #imageLiteral(resourceName: "ic_chat_time").size.height)
    static let statusHighlightTintColor = UIColor.darkTheme
    static let margin = Margin(leading: 16, trailing: 10, top: 0, bottom: 8)
    static let statusLeftMargin: CGFloat = 4
    static let timeFont = UIFont.systemFont(ofSize: 11, weight: .light)
    static let fullnameFont = UIFont.systemFont(ofSize: 14)
    static let identityIconLeftMargin: CGFloat = 4
    static let identityIconSize = #imageLiteral(resourceName: "ic_user_bot").size
    static let minFullnameWidth: CGFloat = 44
    
    class var bubbleImageProvider: BubbleImageProvider.Type {
        return BubbleImageProvider.self
    }
    
    internal(set) var statusImage: UIImage?
    internal(set) var statusTintColor = UIColor.infoGray
    internal(set) var timeSize = CGSize.zero
    internal(set) var fullnameFrame = CGRect(x: 24, y: 1, width: 24, height: 23)
    internal(set) var fullnameColor = UIColor.darkTheme
    internal(set) var timeFrame = CGRect(x: 0, y: 0, width: 0, height: 12)
    internal(set) var statusFrame = CGRect.zero
    internal(set) var fullnameWidth: CGFloat = 0
    internal(set) var identityIconFrame = CGRect(origin: .zero, size: DetailInfoMessageViewModel.identityIconSize)
    
    internal var statusNormalTintColor: UIColor {
        return .infoGray
    }

    internal var maxContentWidth: CGFloat {
        return layoutWidth
            - MessageViewModel.backgroundImageMargin.horizontal
            - contentMargin.horizontal
    }
    
    internal var showStatusImage: Bool {
        return !style.contains(.received) || message.status == MessageStatus.FAILED.rawValue
    }
    
    var status: String {
        get {
            return message.status
        }
        set {
            if showStatusImage {
                switch newValue {
                case MessageStatus.SENDING.rawValue, MessageStatus.FAILED.rawValue, MessageStatus.UNKNOWN.rawValue:
                    statusImage = DetailInfoMessageViewModel.pendingImage
                    statusTintColor = statusNormalTintColor
                case MessageStatus.SENT.rawValue:
                    statusImage = DetailInfoMessageViewModel.checkmarkImage
                    statusTintColor = statusNormalTintColor
                case MessageStatus.DELIVERED.rawValue:
                    statusImage = DetailInfoMessageViewModel.doubleCheckmarkImage
                    statusTintColor = statusNormalTintColor
                case MessageStatus.READ.rawValue:
                    statusImage = DetailInfoMessageViewModel.doubleCheckmarkImage
                    statusTintColor = DetailInfoMessageViewModel.statusHighlightTintColor
                default:
                    return
                }
            } else {
                if newValue == MessageStatus.FAILED.rawValue {
                    statusImage = DetailInfoMessageViewModel.pendingImage
                    statusTintColor = statusNormalTintColor
                } else {
                    statusImage = nil
                }
            }
            message.status = newValue
        }
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        fullnameWidth = (message.userFullName as NSString)
            .boundingRect(with: UIView.layoutFittingExpandedSize, options: [], attributes: [.font: DetailInfoMessageViewModel.fullnameFont], context: nil)
            .width
        super.init(message: message, style: style, fits: layoutWidth)
        status = message.status
    }
    
    override func didSetStyle() {
        super.didSetStyle()
        timeSize = ceil((time as NSString).size(withAttributes: [.font: DetailInfoMessageViewModel.timeFont]))
        let margin = DetailInfoMessageViewModel.margin
        timeFrame = CGRect(x: backgroundImageFrame.maxX - timeSize.width,
                           y: backgroundImageFrame.maxY - margin.bottom - timeSize.height,
                           width: timeSize.width,
                           height: timeSize.height)
        backgroundImage = type(of: self).bubbleImageProvider.bubbleImage(forStyle: style, highlight: false)
        if showStatusImage {
            statusFrame.size = DetailInfoMessageViewModel.statusImageSize
        } else {
            statusFrame.size = .zero
        }
        if style.contains(.received) {
            if message.status == MessageStatus.FAILED.rawValue {
                timeFrame.origin.x -= (margin.trailing + DetailInfoMessageViewModel.statusLeftMargin + statusFrame.width)
            } else {
                timeFrame.origin.x -= margin.trailing
            }
        } else {
            timeFrame.origin.x -= (margin.leading + DetailInfoMessageViewModel.statusLeftMargin + statusFrame.width)
        }
        if style.contains(.fullname) {
            let index = message.userId.positiveHashCode() % UIColor.usernameColors.count
            fullnameColor = UIColor.usernameColors[index]
        }
        statusFrame.origin = CGPoint(x: timeFrame.maxX + DetailInfoMessageViewModel.statusLeftMargin,
                                     y: timeFrame.origin.y + (timeFrame.height - statusFrame.height) / 2)
        fullnameFrame.size.width = max(DetailInfoMessageViewModel.minFullnameWidth, min(fullnameWidth, maxContentWidth))
        identityIconFrame.origin = CGPoint(x: fullnameFrame.maxX + DetailInfoMessageViewModel.identityIconLeftMargin,
                                           y: fullnameFrame.origin.y + (fullnameFrame.height - identityIconFrame.height) / 2)
    }
    
}

extension DetailInfoMessageViewModel {
    
    class BubbleImageProvider {
        
        internal class var left: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_left")
        }
        
        internal class var leftTail: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_left_tail")
        }
        
        internal class var right: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_right")
        }
        
        internal class var rightTail: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_right_tail")
        }
        
        internal class var leftHighlight: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_left_highlight")
        }
        
        internal class var leftTailHighlight: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_left_tail_highlight")
        }
        
        internal class var rightHighlight: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_right_highlight")
        }
        
        internal class var rightTailHighlight: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_right_tail_highlight")
        }
        
        class func bubbleImage(forStyle style: Style, highlight: Bool) -> UIImage {
            if style.contains(.received) {
                if style.contains(.tail) {
                    return highlight ? leftTailHighlight : leftTail
                } else {
                    return highlight ? leftHighlight : left
                }
            } else {
                if style.contains(.tail) {
                    return highlight ? rightTailHighlight : rightTail
                } else {
                    return highlight ? rightHighlight : right
                }
            }
        }
        
    }
    
    class LightRightBubbleImageProvider: BubbleImageProvider {
        
        override class var right: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_right_white")
        }
        
        override class var rightTail: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_right_white_tail")
        }
        
        override class var rightHighlight: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_right_white_highlight")
        }
        
        override class var rightTailHighlight: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_right_white_tail_highlight")
        }
        
    }
    
}
