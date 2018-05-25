import UIKit

class ReceiveMoneyWindow: BottomSheetView {

    @IBOutlet weak var qrcodeAvatarImageView: AvatarImageView!
    @IBOutlet weak var qrcodeImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()

        qrcodeAvatarImageView.layer.borderColor = UIColor.white.cgColor
        qrcodeAvatarImageView.layer.borderWidth = 2
        layoutIfNeeded()
        if let account = AccountAPI.shared.account {
            qrcodeImageView.image = UIImage(qrcode: "mixin://transfer/\(account.user_id)", size: qrcodeImageView.frame.width)
            qrcodeAvatarImageView.setImage(with: account)
        }
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissView()
    }

    @IBAction func moreAction(_ sender: Any) {

    }

    class func instance() -> ReceiveMoneyWindow {
        return Bundle.main.loadNibNamed("ReceiveMoneyWindow", owner: nil, options: nil)?.first as! ReceiveMoneyWindow
    }
}

