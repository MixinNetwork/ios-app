import UIKit

protocol PinMessagesViewDelegate: AnyObject {
    func pinMessagesViewDidTapPin(_ view: PinMessagesView)
    func pinMessagesViewDidTapClose(_ view: PinMessagesView)
    func pinMessagesViewDidTapMessage(_ view: PinMessagesView)
}

final class PinMessagesView: UIView {

    weak var delegate: PinMessagesViewDelegate?
    
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
        delegate?.pinMessagesViewDidTapClose(self)
    }
    
    @IBAction func tapPinAction(_ sender: Any) {
        delegate?.pinMessagesViewDidTapPin(self)
    }
    
    @IBAction func tapMessageAction(_ sender: Any) {
        delegate?.pinMessagesViewDidTapMessage(self)
    }
    
}

extension PinMessagesView {
    
    func updateCount(_ count: Int) {
        countLabel.text = "\(count)"
    }
    
    func update(content: String, count: Int) {
        closeButton.isHidden = false
        wrapperButton.isHidden = false
        messageLabel.isHidden = false
        messageLabel.text = content
        countLabel.text = "\(count)"
    }
    
    func hideMessage() {
        closeButton.isHidden = true
        wrapperButton.isHidden = true
        messageLabel.isHidden = true
    }
    
}

