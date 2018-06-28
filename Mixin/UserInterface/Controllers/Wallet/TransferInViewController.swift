import UIKit

class TransferInViewController: UIViewController {

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var qrcodeAvatarImageView: AvatarImageView!
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var fullNameLabel: UILabel!
    @IBOutlet weak var identifyNumberLabel: UILabel!
    @IBOutlet weak var addressButton: UIButton!
    @IBOutlet weak var confirmationLabel: UILabel!

    private var asset: AssetItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.layoutIfNeeded()

        if !asset.publicKey.isEmpty {
            qrcodeImageView.image = UIImage(qrcode: asset.publicKey, size: qrcodeImageView.frame.size)
            addressButton.setTitle(asset.publicKey, for: .normal)
        }
        confirmationLabel.text = Localized.WALLET_DEPOSIT_CONFIRMATIONS(confirmations: asset.confirmations)
        avatarImageView.sd_setImage(with: URL(string: asset.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
        qrcodeAvatarImageView.sd_setImage(with: URL(string: asset.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
        qrcodeAvatarImageView.layer.borderColor = UIColor.white.cgColor
        qrcodeAvatarImageView.layer.borderWidth = 2
        fullNameLabel.text = asset.name
        identifyNumberLabel.text = asset.symbol
    }

    @IBAction func copyAction(_ sender: Any) {
        UIPasteboard.general.string = asset.publicKey
        NotificationCenter.default.postOnMain(name: .ToastMessageDidAppear, object: Localized.TOAST_COPIED)
    }

    class func instance(asset: AssetItem) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "transfer_in") as! TransferInViewController
        vc.asset = asset
        return ContainerViewController.instance(viewController: vc, title: Localized.WALLET_DEPOSIT)
    }
}
