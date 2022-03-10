import UIKit

@objc protocol MultipleSelectionActionViewDelegate {
    @objc optional func multipleSelectionActionViewDidTapCancel(_ view: MultipleSelectionActionView)
    @objc optional func multipleSelectionActionViewDidTapAction(_ view: MultipleSelectionActionView)
}

class MultipleSelectionActionView: UIView {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    @IBOutlet weak var hideCancelButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var showCancelButtonConstraint: NSLayoutConstraint!
    
    weak var delegate: MultipleSelectionActionViewDelegate?
    
    var preferredHeight: CGFloat {
        50 + safeAreaInsets.bottom
    }
    
    var showCancelButton: Bool = true {
        didSet {
            if showCancelButton {
                label.textAlignment = .center
                cancelButton.isHidden = false
                showCancelButtonConstraint.priority = .defaultHigh
                hideCancelButtonConstraint.priority = .defaultLow
            } else {
                label.textAlignment = .left
                cancelButton.isHidden = true
                showCancelButtonConstraint.priority = .defaultLow
                hideCancelButtonConstraint.priority = .defaultHigh
            }
        }
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

    @IBAction func didTapActionButton(_ sender: Any) {
        delegate?.multipleSelectionActionViewDidTapAction?(self)
    }
    
    @IBAction func didTapCancelButton(_ sender: Any) {
        delegate?.multipleSelectionActionViewDidTapCancel?(self)
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
