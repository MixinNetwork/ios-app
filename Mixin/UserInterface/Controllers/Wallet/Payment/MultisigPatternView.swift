import UIKit
import MixinServices

final class MultisigPatternView: UIView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    
    @IBOutlet weak var firstSenderAvatarView: BorderedAvatarImageView!
    @IBOutlet weak var secondSenderAvatarView: BorderedAvatarImageView!
    @IBOutlet weak var moreSenderView: CornerView!
    @IBOutlet weak var moreSenderCountLabel: UILabel!
    
    @IBOutlet weak var actionImageView: UIImageView!
    
    @IBOutlet weak var firstReceiverAvatarView: BorderedAvatarImageView!
    @IBOutlet weak var secondReceiverAvatarView: BorderedAvatarImageView!
    @IBOutlet weak var moreReceiverView: CornerView!
    @IBOutlet weak var moreReceiverCountLabel: UILabel!
    
    @IBOutlet weak var showSendersButton: UIButton!
    @IBOutlet weak var showReceiversButton: UIButton!
    
    func reloadData(senders: [UserItem], receivers: [UserItem], action: MultisigAction) {
        if senders.count > 0 {
            firstSenderAvatarView.setImage(with: senders[0])
        }
        if senders.count > 1 {
            secondSenderAvatarView.setImage(with: senders[1])
            secondSenderAvatarView.isHidden = false
        } else {
            secondSenderAvatarView.isHidden = true
        }
        if senders.count > 2 {
            moreSenderCountLabel.text = "+\(senders.count - 2)"
            moreSenderView.isHidden = false
        } else {
            moreSenderView.isHidden = true
        }
        
        if receivers.count > 0 {
            firstReceiverAvatarView.setImage(with: receivers[0])
        }
        if receivers.count > 1 {
            secondReceiverAvatarView.setImage(with: receivers[1])
            secondReceiverAvatarView.isHidden = false
        } else {
            secondReceiverAvatarView.isHidden = true
        }
        if receivers.count > 2 {
            moreReceiverCountLabel.text = "+\(receivers.count - 2)"
            moreReceiverView.isHidden = false
        } else {
            moreReceiverView.isHidden = true
        }
        
        switch action {
        case .sign:
            actionImageView.image = R.image.multisig_sign()
        case .unlock:
            actionImageView.image = R.image.multisig_revoke()
        }
    }
    
}
