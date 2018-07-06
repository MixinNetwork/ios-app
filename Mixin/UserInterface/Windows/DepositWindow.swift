import UIKit

class DepositWindow: BottomSheetView {

    @IBOutlet weak var qrcodeAvatarImageView: AvatarImageView!
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var qrcodeView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var blockchainImageView: CornerImageView!

    private var asset: AssetItem!

    func presentView(asset: AssetItem, isDisplayAccountName: Bool) {
        self.asset = asset

        if isDisplayAccountName {
            titleLabel.text = Localized.WALLET_ACCOUNT_NAME
            subtitleLabel.text = asset.accountName
            qrcodeImageView.image = UIImage(qrcode: asset.accountName ?? "", size: qrcodeImageView.frame.size)
        } else {
            titleLabel.text = Localized.WALLET_ACCOUNT_MEMO
            subtitleLabel.text = asset.accountMemo
            qrcodeImageView.image = UIImage(qrcode: asset.accountMemo ?? "", size: qrcodeImageView.frame.size)
        }
        qrcodeAvatarImageView.sd_setImage(with: URL(string: asset.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
        qrcodeAvatarImageView.layer.borderColor = UIColor.white.cgColor
        qrcodeAvatarImageView.layer.borderWidth = 2
        if let chainIconUrl = asset.chainIconUrl {
            blockchainImageView.sd_setImage(with: URL(string: chainIconUrl))
            blockchainImageView.isHidden = false
        } else {
            blockchainImageView.isHidden = true
        }
        super.presentView()
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissView()
    }

    class func instance() -> DepositWindow {
        return Bundle.main.loadNibNamed("DepositWindow", owner: nil, options: nil)?.first as! DepositWindow
    }
}
