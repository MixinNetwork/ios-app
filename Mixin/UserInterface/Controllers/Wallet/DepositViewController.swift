import UIKit

class DepositViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var upperDepositFieldView: DepositFieldView!
    @IBOutlet weak var lowerDepositFieldView: DepositFieldView!
    @IBOutlet weak var hintLabel: UILabel!
    
    private var asset: AssetItem!
    private lazy var depositWindow = QrcodeWindow.instance()

    private static let depositRemindEnable = 0
    private static let depositRemindAllowDisable = 1
    private static let depositRemindDisabled = -1
    
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
            upperDepositFieldView.delegate = self
            
            lowerDepositFieldView.titleLabel.text = Localized.WALLET_ACCOUNT_MEMO
            lowerDepositFieldView.contentLabel.text = memo
            let memoImage = UIImage(qrcode: memo, size: lowerDepositFieldView.qrCodeImageView.bounds.size)
            lowerDepositFieldView.qrCodeImageView.image = memoImage
            lowerDepositFieldView.iconImageView.sd_setImage(with: iconUrl, completed: nil)
            lowerDepositFieldView.chainImageView.sd_setImage(with: chainIconUrl, completed: nil)
            lowerDepositFieldView.delegate = self

            let notice = Localized.WALLET_DEPOSIT_ACCOUNT_NOTICE(symbol: asset.symbol, confirmations: asset.confirmations)
            hintLabel.text = notice

            if WalletUserDefault.shared.depositRemind != DepositViewController.depositRemindDisabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    guard let weakself = self else {
                        return
                    }

                    let alc = UIAlertController(title: "", message: notice, preferredStyle: .alert)
                    if WalletUserDefault.shared.depositRemind == DepositViewController.depositRemindAllowDisable {
                        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_NO_REMIND, style: .default, handler: { (_) in
                            WalletUserDefault.shared.depositRemind = DepositViewController.depositRemindDisabled
                        }))
                    }
                    alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_OK, style: .default, handler: { (_) in
                        WalletUserDefault.shared.depositRemind = DepositViewController.depositRemindAllowDisable
                    }))
                    weakself.present(alc, animated: true, completion: nil)
                }
            }
        } else if let publicKey = asset.publicKey, !publicKey.isEmpty {
            upperDepositFieldView.titleLabel.text = Localized.WALLET_ADDRESS
            upperDepositFieldView.contentLabel.text = publicKey
            let image = UIImage(qrcode: publicKey, size: upperDepositFieldView.qrCodeImageView.bounds.size)
            upperDepositFieldView.qrCodeImageView.image = image
            upperDepositFieldView.iconImageView.sd_setImage(with: iconUrl, completed: nil)
            upperDepositFieldView.chainImageView.sd_setImage(with: chainIconUrl, completed: nil)
            upperDepositFieldView.delegate = self
            
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

    func imageBarRightButton() -> UIImage? {
        return #imageLiteral(resourceName: "ic_titlebar_help")
    }

    func barRightButtonTappedAction() {
        if asset.isAccount {
            UIApplication.shared.openURL(url: "https://mixinmessenger.zendesk.com/hc/en-us/articles/360023738212-How-to-deposit-EOS-to-Mixin-Messenger-")
        } else {
            UIApplication.shared.openURL(url: "https://mixinmessenger.zendesk.com/hc/en-us/articles/360018789931-How-to-deposit-on-Mixin-Messenger-")
        }
    }
    
}

extension DepositViewController: DepositFieldViewDelegate {
    
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
