import UIKit
import MixinServices

class DepositNotSupportedViewController: UIViewController {
    
    @IBOutlet weak var label: TextLabel!
    
    @IBOutlet weak var wrapperViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var wrapperViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelHeightConstraint: NSLayoutConstraint!
    
    private var asset: AssetItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        container?.setSubtitle(subtitle: asset.symbol)
        view.layoutIfNeeded()
        
        label.delegate = self
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.lineSpacing = 10
        label.textColor = R.color.red()!
        label.linkColor = .theme
        label.detectLinks = false
        let text = R.string.localizable.not_supported_deposit(asset.name, asset.name)
        label.text = text
        let linkRange = (text as NSString).range(of: R.string.localizable.learn_more(), options: [.backwards, .caseInsensitive])
        if linkRange.location != NSNotFound && linkRange.length != 0 {
            label.additionalLinksMap = [linkRange: .notSupportedDeposit]
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let labelWidth = view.bounds.width
            - labelLeadingConstraint.constant
            - labelTrailingConstraint.constant
            - wrapperViewLeadingConstraint.constant
            - wrapperViewTrailingConstraint.constant
        let sizeToFitLabel = CGSize(width: labelWidth, height: UIView.layoutFittingExpandedSize.height)
        let textLabelHeight = label.sizeThatFits(sizeToFitLabel).height
        labelHeightConstraint.constant = textLabelHeight
    }
    
    class func instance(asset: AssetItem) -> UIViewController {
        let vc = R.storyboard.wallet.deposit_not_supported()!
        vc.asset = asset
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.deposit())
    }
    
}

extension DepositNotSupportedViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        true
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.ic_titlebar_help()
    }
    
    func barRightButtonTappedAction() {
        UIApplication.shared.openURL(url: .deposit)
    }
    
}

extension DepositNotSupportedViewController: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        
    }
    
}
