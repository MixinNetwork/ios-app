import UIKit

protocol PinMessageBannerViewDelegate: AnyObject {
    func pinMessageBannerViewDidTapPin(_ view: PinMessageBannerView)
    func pinMessageBannerViewDidTapClose(_ view: PinMessageBannerView)
    func pinMessageBannerViewDidTapPreview(_ view: PinMessageBannerView)
}

final class PinMessageBannerView: UIView {
    
    weak var delegate: PinMessageBannerViewDelegate?
    
    @IBOutlet weak var pinButton: UIButton!
    @IBOutlet weak var countLabel: InsetLabel!
    @IBOutlet weak var wrapperButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var messageLabel: UILabel!
    
    @IBAction func tapCloseAction(_ sender: Any) {
        delegate?.pinMessageBannerViewDidTapClose(self)
    }
    
    @IBAction func tapPinAction(_ sender: Any) {
        delegate?.pinMessageBannerViewDidTapPin(self)
    }
    
    @IBAction func tapMessageAction(_ sender: Any) {
        delegate?.pinMessageBannerViewDidTapPreview(self)
    }
    
}

extension PinMessageBannerView {
    
    func updateMessageCount(_ count: Int) {
        countLabel.text = "\(count)"
    }
    
    func update(preview: String, count: Int) {
        closeButton.isHidden = false
        wrapperButton.isHidden = false
        messageLabel.isHidden = false
        countLabel.isHidden = false
        messageLabel.text = preview
        countLabel.text = "\(count)"
    }
    
    func hideMessagePreviewAndCount() {
        countLabel.isHidden = true
        closeButton.isHidden = true
        wrapperButton.isHidden = true
        messageLabel.isHidden = true
    }
    
}

