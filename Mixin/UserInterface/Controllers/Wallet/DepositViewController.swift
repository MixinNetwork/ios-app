import UIKit
import MixinServices

class DepositViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var upperDepositFieldView: DepositFieldView!
    @IBOutlet weak var lowerDepositFieldView: DepositFieldView!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var warningView: UIView!
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
        
        let tips: String
        if !asset.tag.isEmpty {
            if asset.usesTag {
                lowerDepositFieldView.titleLabel.text = R.string.localizable.wallet_address_tag()
            } else {
                lowerDepositFieldView.titleLabel.text = R.string.localizable.wallet_address_memo()
            }
            lowerDepositFieldView.contentLabel.text = asset.tag
            let memoImage = UIImage(qrcode: asset.tag, size: lowerDepositFieldView.qrCodeImageView.bounds.size)
            lowerDepositFieldView.qrCodeImageView.image = memoImage
            lowerDepositFieldView.assetIconView.setIcon(asset: asset)
            lowerDepositFieldView.shadowView.hasLowerShadow = false
            lowerDepositFieldView.delegate = self
            tips = R.string.localizable.wallet_deposit_account_attention(asset.symbol)
        } else {
            lowerDepositFieldView.isHidden = true
            if asset.reserve.doubleValue > 0 {
                tips = R.string.localizable.wallet_deposit_attention_minimum(asset.reserve, asset.chain?.symbol ?? "")
            } else {
                tips = R.string.localizable.wallet_deposit_attention()
            }
        }
        hintLabel.attributedText = bulletAttributedString(with: asset.depositTips)
        
        let vc = DepositNoticeViewController(tips: tips)
        if !asset.tag.isEmpty {
            warningLabel.text = tips
            vc.dismissCompletion = {
                UIView.animate(withDuration: 0.3) {
                    self.warningView.isHidden = false
                }
            }
        }
        present(vc, animated: true, completion: nil)
    }
    
    class func instance(asset: AssetItem) -> UIViewController {
        let vc = R.storyboard.wallet.deposit()!
        vc.asset = asset
        return ContainerViewController.instance(viewController: vc, title: Localized.WALLET_DEPOSIT)
    }
    
}

extension DepositViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.ic_titlebar_help()
    }
    
    func barRightButtonTappedAction() {
        UIApplication.shared.openURL(url: "https://mixinmessenger.zendesk.com/hc/articles/360018789931")
    }
    
}

extension DepositViewController: DepositFieldViewDelegate {
    
    func depositFieldViewDidCopyContent(_ view: DepositFieldView) {
        showAutoHiddenHud(style: .notification, text: Localized.TOAST_COPIED)
    }
    
    func depositFieldViewDidSelectShowQRCode(_ view: DepositFieldView) {
        depositWindow.render(title: view.titleLabel.text ?? "",
                             content: view.contentLabel.text ?? "",
                             asset: asset)
        depositWindow.presentView()
    }
}

extension DepositViewController {
    
    private func bulletAttributedString(with strings: [String]) -> NSAttributedString {
        let indentation: CGFloat = 10
        let nonOptions = [NSTextTab.OptionKey: Any]()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: indentation, options: nonOptions)]
        paragraphStyle.defaultTabInterval = indentation
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 6
        paragraphStyle.headIndent = indentation
        let attributes: [NSAttributedString.Key: Any] = [
            .font: hintLabel.font ?? .systemFont(ofSize: 12),
            .foregroundColor: hintLabel.textColor ?? .accessoryText,
            .paragraphStyle: paragraphStyle
        ]
        let bullet = "• "
        let bulletListString = NSMutableAttributedString()
        for string in strings {
            let formattedString = "\(bullet)\t\(string)\n"
            let attributedString = NSMutableAttributedString(string: formattedString)
            attributedString.addAttributes(attributes, range: NSMakeRange(0, attributedString.length))
            bulletListString.append(attributedString)
        }
        return bulletListString
    }
    
}
