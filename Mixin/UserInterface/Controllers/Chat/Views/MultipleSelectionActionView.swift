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
            updateButtonAvailability()
        }
    }
    
    var numberOfSelection = 0 {
        didSet {
            label.text = R.string.localizable.chat_number_of_selection("\(numberOfSelection)")
            updateButtonAvailability()
        }
    }
    
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        frame.size.height = preferredHeight
    }
    
    private func updateButtonAvailability() {
        switch intent {
        case .forward:
            button.isEnabled = numberOfSelection > 0
                && numberOfSelection <= maxNumberOfTranscriptChildren
        case .delete:
            button.isEnabled = numberOfSelection > 0
        }
    }
    
}
