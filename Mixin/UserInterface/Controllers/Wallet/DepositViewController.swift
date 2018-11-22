import UIKit

class DepositViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var upperDepositFieldView: DepositFieldView!
    @IBOutlet weak var lowerDepositFieldView: DepositFieldView!
    @IBOutlet weak var hintLabel: UILabel!
    
    private var asset: AssetItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        container?.subtitleLabel.text = asset.symbol
        container?.subtitleLabel.isHidden = false
        view.layoutIfNeeded()
        let iconUrl = URL(string: asset.iconUrl)
        let chainIconUrl = URL(string: asset.chainIconUrl ?? "")
        if asset.isAccount, let name = asset.accountName, let memo = asset.accountTag {
            upperDepositFieldView.titleLabel.text = Localized.WALLET_ACCOUNT_NAME
            upperDepositFieldView.contentLabel.text = name
            let nameImage = UIImage(qrcode: name, size: upperDepositFieldView.qrCodeImageView.bounds.size)
            upperDepositFieldView.qrCodeImageView.image = nameImage
            upperDepositFieldView.iconImageView.sd_setImage(with: iconUrl, completed: nil)
            upperDepositFieldView.chainImageView.sd_setImage(with: chainIconUrl, completed: nil)
            
            lowerDepositFieldView.titleLabel.text = Localized.WALLET_ACCOUNT_MEMO
            lowerDepositFieldView.contentLabel.text = memo
            let memoImage = UIImage(qrcode: memo, size: lowerDepositFieldView.qrCodeImageView.bounds.size)
            lowerDepositFieldView.qrCodeImageView.image = memoImage
            lowerDepositFieldView.iconImageView.sd_setImage(with: iconUrl, completed: nil)
            lowerDepositFieldView.chainImageView.sd_setImage(with: chainIconUrl, completed: nil)
            
            hintLabel.text = Localized.WALLET_DEPOSIT_ACCOUNT_NOTICE(symbol: asset.symbol, confirmations: asset.confirmations)
        } else if let publicKey = asset.publicKey, !publicKey.isEmpty {
            upperDepositFieldView.titleLabel.text = Localized.WALLET_ADDRESS
            upperDepositFieldView.contentLabel.text = publicKey
            let image = UIImage(qrcode: publicKey, size: upperDepositFieldView.qrCodeImageView.bounds.size)
            upperDepositFieldView.qrCodeImageView.image = image
            upperDepositFieldView.iconImageView.sd_setImage(with: iconUrl, completed: nil)
            upperDepositFieldView.chainImageView.sd_setImage(with: chainIconUrl, completed: nil)
            lowerDepositFieldView.isHidden = true
            hintLabel.text = Localized.WALLET_DEPOSIT_CONFIRMATIONS(confirmations: asset.confirmations)
        } else {
            scrollView.isHidden = true
        }
    }
    
    class func instance(asset: AssetItem) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "deposit") as! DepositViewController
        vc.asset = asset
        return ContainerViewController.instance(viewController: vc, title: Localized.WALLET_DEPOSIT)
    }
    
}

extension DepositViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
}
