import UIKit

class DepositWindow: BottomSheetView {
    
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var chainImageView: CornerImageView!
    @IBOutlet weak var qrcodeView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    enum Content {
        case address, name, memo
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        iconImageView.layer.borderColor = UIColor.white.cgColor
        iconImageView.layer.borderWidth = 2
    }
    
    func render(asset: AssetItem, content: Content) {
        iconImageView.sd_cancelCurrentImageLoad()
        chainImageView.sd_cancelCurrentImageLoad()
        iconImageView.sd_setImage(with: URL(string: asset.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
        if let chainIconUrl = asset.chainIconUrl {
            chainImageView.sd_setImage(with: URL(string: chainIconUrl))
            chainImageView.isHidden = false
        } else {
            chainImageView.isHidden = true
        }
        switch content {
        case .address:
            titleLabel.text = Localized.WALLET_ADDRESS
            subtitleLabel.text = nil
            qrcodeImageView.image = UIImage(qrcode: asset.publicKey ?? "", size: qrcodeImageView.frame.size)
        case .name:
            titleLabel.text = Localized.WALLET_ACCOUNT_NAME
            subtitleLabel.text = asset.accountName
            qrcodeImageView.image = UIImage(qrcode: asset.accountName ?? "", size: qrcodeImageView.frame.size)
        case .memo:
            titleLabel.text = Localized.WALLET_ACCOUNT_MEMO
            subtitleLabel.text = asset.accountTag
            qrcodeImageView.image = UIImage(qrcode: asset.accountTag ?? "", size: qrcodeImageView.frame.size)
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissView()
    }
    
    class func instance() -> DepositWindow {
        return Bundle.main.loadNibNamed("DepositWindow", owner: nil, options: nil)?.first as! DepositWindow
    }
    
}
