import UIKit

class MultipleSelectionActionView: UIView {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    
    var preferredHeight: CGFloat {
        50 + safeAreaInsets.bottom
    }
    
    var intent: MultipleSelectionIntent = .forward {
        didSet {
            let image: UIImage?
            switch intent {
            case .forward:
                image = R.image.conversation.ic_selection_action_forward()
            case .delete:
                image = R.image.conversation.ic_selection_action_delete()
            }
            button.setImage(image, for: .normal)
        }
    }
    
    var numberOfSelection = 0 {
        didSet {
            label.text = R.string.localizable.chat_number_of_selection("\(numberOfSelection)")
            button.isEnabled = numberOfSelection > 0
        }
    }
    
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        frame.size.height = preferredHeight
    }
    
}
