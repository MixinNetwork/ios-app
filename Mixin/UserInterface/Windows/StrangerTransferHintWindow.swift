import UIKit
import MixinServices

final class StrangerTransferHintWindow: BottomSheetView {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var hintLabel: LineHeightLabel!
    
    var onContinue: (() -> Void)?
    var onCancel: (() -> Void)?
    
    private var canDismiss = false

    override func dismissPopupControllerAnimated() {
        guard canDismiss else {
            return
        }
        super.dismissPopupControllerAnimated()
    }
    
    class func instance(userItem: UserItem) -> StrangerTransferHintWindow {
        let window = R.nib.strangerTransferHintWindow(owner: self)!
        window.avatarImageView.setImage(with: userItem)
        window.nameLabel.text = userItem.fullName
        window.idLabel.text = R.string.localizable.contact_identity_number(userItem.identityNumber)
        window.hintLabel.text = R.string.localizable.wallet_transfer_stranger_hint(userItem.identityNumber)
        return window
    }
    
    @IBAction func continueAction(_ sender: Any) {
        canDismiss = true
        onContinue?()
        dismissPopupControllerAnimated()
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        canDismiss = true
        onCancel?()
        dismissPopupControllerAnimated()
    }
    
}
