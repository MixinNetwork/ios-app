import UIKit

protocol BubbleImageSet {
    
    static var left: UIImage { get }
    static var leftTail: UIImage { get }
    
    static var right: UIImage { get }
    static var rightTail: UIImage { get }
    
    static var leftHighlight: UIImage { get }
    static var leftTailHighlight: UIImage { get }
    
    static var rightHighlight: UIImage { get }
    static var rightTailHighlight: UIImage { get }
    
}

extension BubbleImageSet {
    
    static func image(forStyle style: MessageViewModel.Style, highlight: Bool) -> UIImage {
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

class GeneralBubbleImageSet: BubbleImageSet {
    
    class var left: UIImage {
        return R.image.ic_chat_bubble_left()!
    }
    
    class var leftTail: UIImage {
        return R.image.ic_chat_bubble_left_tail()!
    }
    
    class var right: UIImage {
        return R.image.ic_chat_bubble_right()!
    }
    
    class var rightTail: UIImage {
        return R.image.ic_chat_bubble_right_tail()!
    }
    
    class var leftHighlight: UIImage {
        return R.image.ic_chat_bubble_left_highlight()!
    }
    
    class var leftTailHighlight: UIImage {
        return R.image.ic_chat_bubble_left_tail_highlight()!
    }
    
    class var rightHighlight: UIImage {
        return R.image.ic_chat_bubble_right_highlight()!
    }
    
    class var rightTailHighlight: UIImage {
        return R.image.ic_chat_bubble_right_tail_highlight()!
    }
    
}

class LightRightBubbleImageSet: GeneralBubbleImageSet {
    
    override class var right: UIImage {
        return R.image.ic_chat_bubble_right_white()!
    }
    
    override class var rightTail: UIImage {
        return R.image.ic_chat_bubble_right_white_tail()!
    }
    
    override class var rightHighlight: UIImage {
        return R.image.ic_chat_bubble_right_white_highlight()!
    }
    
    override class var rightTailHighlight: UIImage {
        return R.image.ic_chat_bubble_right_white_tail_highlight()!
    }
    
}

class UnknownBubbleImageSet: GeneralBubbleImageSet {
    
    override class var left: UIImage {
        return R.image.ic_chat_bubble_unknown_left()!
    }
    
    override class var leftTail: UIImage {
        return R.image.ic_chat_bubble_unknown_left_tail()!
    }
    
}

class AppCardBubbleImageSet: GeneralBubbleImageSet {

    override class var leftTail: UIImage {
        return R.image.ic_chat_bubble_left()!
    }
    
    override class var leftTailHighlight: UIImage {
        return R.image.ic_chat_bubble_left_highlight()!
    }
    
}
