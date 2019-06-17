import UIKit

class DepositViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var upperDepositFieldView: DepositFieldView!
    @IBOutlet weak var lowerDepositFieldView: DepositFieldView!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!
    
    private var asset: AssetItem!
    private lazy var depositWindow = QrcodeWindow.instance()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        container?.setSubtitle(subtitle: asset.symbol)
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
            upperDepositFieldView.shadowView.hasLowerShadow = true
            upperDepositFieldView.delegate = self
            
            lowerDepositFieldView.titleLabel.text = Localized.WALLET_ACCOUNT_MEMO
            lowerDepositFieldView.contentLabel.text = memo
            let memoImage = UIImage(qrcode: memo, size: lowerDepositFieldView.qrCodeImageView.bounds.size)
            lowerDepositFieldView.qrCodeImageView.image = memoImage
            lowerDepositFieldView.iconImageView.sd_setImage(with: iconUrl, completed: nil)
            lowerDepositFieldView.chainImageView.sd_setImage(with: chainIconUrl, completed: nil)
            lowerDepositFieldView.shadowView.hasLowerShadow = false
            lowerDepositFieldView.delegate = self
        } else if let publicKey = asset.publicKey, !publicKey.isEmpty {
            upperDepositFieldView.titleLabel.text = Localized.WALLET_ADDRESS
            upperDepositFieldView.contentLabel.text = publicKey
            let image = UIImage(qrcode: publicKey, size: upperDepositFieldView.qrCodeImageView.bounds.size)
            upperDepositFieldView.qrCodeImageView.image = image
            upperDepositFieldView.iconImageView.sd_setImage(with: iconUrl, completed: nil)
            upperDepositFieldView.chainImageView.sd_setImage(with: chainIconUrl, completed: nil)
            upperDepositFieldView.shadowView.hasLowerShadow = false
            upperDepositFieldView.delegate = self
            
            lowerDepositFieldView.isHidden = true
        } else {
            scrollView.isHidden = true
        }

        hintLabel.text = asset.depositTips
        if asset.isAccount {
            warningLabel.text = R.string.localizable.wallet_deposit_account_attention(asset.symbol)
        } else {
            warningLabel.text = R.string.localizable.wallet_deposit_attention()
        }

        if !WalletUserDefault.shared.depositTipRemind.contains(asset.chainId) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let weakself = self else {
                    return
                }

                DepositTipWindow.instance().render(asset: weakself.asset).presentPopupControllerAnimated()
            }
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

    func imageBarRightButton() -> UIImage? {
        return #imageLiteral(resourceName: "ic_titlebar_help")
    }

    func barRightButtonTappedAction() {
        if asset.isAccount {
            UIApplication.shared.openURL(url: "https://mixinmessenger.zendesk.com/hc/articles/360023738212")
        } else {
            UIApplication.shared.openURL(url: "https://mixinmessenger.zendesk.com/hc/en-us/articles/360018789931-How-to-deposit-on-Mixin-Messenger-")
        }
    }
    
}

extension DepositViewController: DepositFieldViewDelegate {
    
    func depositFieldViewDidCopyContent(_ view: DepositFieldView) {
        showAutoHiddenHud(style: .notification, text: Localized.TOAST_COPIED)
    }
    
    func depositFieldViewDidSelectShowQRCode(_ view: DepositFieldView) {
        if asset.isAccount {
            if view == upperDepositFieldView {
                depositWindow.render(title: Localized.WALLET_ACCOUNT_NAME, iconUrl: asset.iconUrl, qrcode: asset.accountName ?? "", leftMarkUrl: asset.chainIconUrl)
            } else {
                depositWindow.render(title: Localized.WALLET_ACCOUNT_MEMO, iconUrl: asset.iconUrl, qrcode: asset.accountTag ?? "", leftMarkUrl: asset.chainIconUrl)
            }
        } else {
            depositWindow.render(title: Localized.WALLET_ADDRESS, iconUrl: asset.iconUrl, qrcode: asset.publicKey ?? "", leftMarkUrl: asset.chainIconUrl)
        }
        depositWindow.presentView()
    }
}
