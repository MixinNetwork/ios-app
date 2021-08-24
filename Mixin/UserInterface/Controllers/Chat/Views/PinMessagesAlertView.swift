import UIKit

protocol PinMessagesAlertViewDelegate: AnyObject {
    func pinMessagesAlertViewDidTapPin(_ view: PinMessagesAlertView)
    func pinMessagesAlertViewDidTapClose(_ view: PinMessagesAlertView)
    func pinMessagesAlertViewDidTapPreview(_ view: PinMessagesAlertView)
}

final class PinMessagesAlertView: UIView {
    
    weak var delegate: PinMessagesAlertViewDelegate?
    
    @IBOutlet weak var pinButton: UIButton!
    @IBOutlet weak var countLabel: RoundedInsetLabel!
    @IBOutlet weak var wrapperButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var messageLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        countLabel.contentInset = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)
    }
    
    @IBAction func tapCloseAction(_ sender: Any) {
        delegate?.pinMessagesAlertViewDidTapClose(self)
    }
    
    @IBAction func tapPinAction(_ sender: Any) {
        delegate?.pinMessagesAlertViewDidTapPin(self)
    }
    
    @IBAction func tapMessageAction(_ sender: Any) {
        delegate?.pinMessagesAlertViewDidTapPreview(self)
    }
    
}

extension PinMessagesAlertView {
    
    func updateMessageCount(_ count: Int) {
        countLabel.text = "\(count)"
    }
    
    func updateMessage(preview: String, count: Int) {
        closeButton.isHidden = false
        wrapperButton.isHidden = false
        messageLabel.isHidden = false
        messageLabel.text = preview
        countLabel.text = "\(count)"
    }
    
    func hideMessagePreview() {
        closeButton.isHidden = true
        wrapperButton.isHidden = true
        messageLabel.isHidden = true
    }
    
}

