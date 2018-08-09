import UIKit

class ReceiveMoneyWindow: MyQRCodeWindow {

    override func render() {
        if let account = AccountAPI.shared.account {
            qrcodeImageView.image = UIImage(qrcode: "mixin://transfer/\(account.user_id)", size: qrcodeImageView.frame.size)
            qrcodeAvatarImageView.setImage(with: account)
        }
    }

    override class func instance() -> ReceiveMoneyWindow {
        return Bundle.main.loadNibNamed("ReceiveMoneyWindow", owner: nil, options: nil)?.first as! ReceiveMoneyWindow
    }
}

