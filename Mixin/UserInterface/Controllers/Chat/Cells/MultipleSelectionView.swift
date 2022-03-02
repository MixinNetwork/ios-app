import UIKit

final class MultipleSelectionView: UIView {

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var actionButton: UIButton!
    
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
            actionButton.setImage(image, for: .normal)
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
            actionButton.isEnabled = numberOfSelection > 0
                && numberOfSelection <= maxNumberOfTranscriptChildren
        case .delete:
            actionButton.isEnabled = numberOfSelection > 0
        }
        cancelButton.isEnabled = numberOfSelection > 0
    }
    
}
