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

        upperDepositFieldView.titleLabel.text = R.string.localizable.wallet_address_destination()
        upperDepositFieldView.contentLabel.text = asset.destination
        let nameImage = UIImage(qrcode: asset.destination, size: upperDepositFieldView.qrCodeImageView.bounds.size)
        upperDepositFieldView.qrCodeImageView.image = nameImage
        upperDepositFieldView.assetIconView.setIcon(asset: asset)
        upperDepositFieldView.shadowView.hasLowerShadow = true
        upperDepositFieldView.delegate = self

        if asset.isAccount {
            if asset.isUseTag {
                lowerDepositFieldView.titleLabel.text = R.string.localizable.wallet_address_tag()
            } else {
                lowerDepositFieldView.titleLabel.text = R.string.localizable.wallet_address_memo()
            }
            lowerDepositFieldView.contentLabel.text = asset.tag
            let memoImage = UIImage(qrcode: asset.tag, size: lowerDepositFieldView.qrCodeImageView.bounds.size)
            lowerDepositFieldView.qrCodeImageView.image = memoImage
            upperDepositFieldView.assetIconView.setIcon(asset: asset)
            lowerDepositFieldView.shadowView.hasLowerShadow = false
            lowerDepositFieldView.delegate = self
        } else {
            lowerDepositFieldView.isHidden = true
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
            UIApplication.shared.openURL(url: "https://mixinmessenger.zendesk.com/hc/articles/360018789931")
        }
    }
    
}

extension DepositViewController: DepositFieldViewDelegate {
    
    func depositFieldViewDidCopyContent(_ view: DepositFieldView) {
        showAutoHiddenHud(style: .notification, text: Localized.TOAST_COPIED)
    }
    
    func depositFieldViewDidSelectShowQRCode(_ view: DepositFieldView) {
        depositWindow.render(title: upperDepositFieldView.titleLabel.text ?? "",
                             content: upperDepositFieldView.contentLabel.text ?? "",
                             asset: asset)
        depositWindow.presentView()
    }
}
