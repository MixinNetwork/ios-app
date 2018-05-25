import UIKit

class MyQRCodeWindow: BottomSheetView {

    @IBOutlet weak var qrcodeAvatarImageView: AvatarImageView!
    @IBOutlet weak var qrcodeImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()

        qrcodeAvatarImageView.layer.borderColor = UIColor.white.cgColor
        qrcodeAvatarImageView.layer.borderWidth = 2
        layoutIfNeeded()
        if let account = AccountAPI.shared.account {
            qrcodeImageView.image = UIImage(qrcode: account.code_url, size: qrcodeImageView.frame.width, foregroundColor: UIColor.systemTint)
            qrcodeAvatarImageView.setImage(with: account)
        }
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissView()
    }

    @IBAction func moreAction(_ sender: Any) {

    }

    class func instance() -> MyQRCodeWindow {
        return Bundle.main.loadNibNamed("MyQRCodeWindow", owner: nil, options: nil)?.first as! MyQRCodeWindow
    }
}
