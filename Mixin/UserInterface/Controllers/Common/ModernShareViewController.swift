import UIKit
import MixinServices

protocol ModernShareContentViewController: UIViewController {
    func shareAsActivity()
    func copyLink()
    func savePhoto()
    func shareToMixinContact()
}

final class ModernShareViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var contentWrapperView: UIView!
    @IBOutlet weak var sendToContactBackgroundView: UIView!
    @IBOutlet weak var sendToContactTitleLabel: UILabel!
    @IBOutlet weak var sendToContactContentLabel: UILabel!
    @IBOutlet weak var actionStackView: UIStackView!
    
    @IBOutlet weak var actionTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var actionHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var actionBottomConstraint: NSLayoutConstraint!
    
    private let contentViewController: any ModernShareContentViewController
    private let contentSize: CGSize
    private let rebating: String?
    
    init<ContentViewController: ModernShareContentViewController>(
        contentViewController: ContentViewController,
        size: CGSize,
        rebatingCode: Referral.RebatingCode?,
    ) {
        self.contentViewController = contentViewController
        self.contentSize = size
        self.rebating = if let rebate = rebatingCode?.rebate {
            PercentageFormatter.string(from: rebate, format: .precision, sign: .never)
        } else {
            nil
        }
        let nib = R.nib.modernShareView
        super.init(nibName: nib.name, bundle: nib.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        
        titleView.titleLabel.text = R.string.localizable.share()
        titleView.closeButton.addTarget(
            self,
            action: #selector(close(_:)),
            for: .touchUpInside
        )
        
        addChild(contentViewController)
        contentWrapperView.addSubview(contentViewController.view)
        contentViewController.view.snp.makeEdgesEqualToSuperview()
        contentViewController.didMove(toParent: self)
        
        sendToContactBackgroundView.layer.cornerRadius = 13
        sendToContactBackgroundView.layer.masksToBounds = true
        sendToContactTitleLabel.text = R.string.localizable.perps_share_to_mixin_contact()
        if let rebating {
            let content = NSMutableAttributedString(
                string: R.string.localizable.perps_share_mixin_contact_desc_with_percent(rebating),
                attributes: [.foregroundColor: R.color.text_tertiary()!]
            )
            let rebatingRange = (content.string as NSString).range(of: rebating)
            content.setAttributes(
                [.foregroundColor: UIColor(displayP3RgbValue: 0xAA71FA)],
                range: rebatingRange
            )
            sendToContactContentLabel.attributedText = content
        } else {
            sendToContactContentLabel.text = R.string.localizable.perps_share_mixin_contact_desc()
        }
        
        addActionButton(
            icon: R.image.web.ic_action_share(),
            text: R.string.localizable.share()
        ) { button in
            button.addTarget(self, action: #selector(shareAsActivity(_:)), for: .touchUpInside)
        }
        addActionButton(
            icon: R.image.web.ic_action_copy(),
            text: R.string.localizable.link()
        ) { button in
            button.addTarget(self, action: #selector(copyLink(_:)), for: .touchUpInside)
        }
        addActionButton(
            icon: R.image.action_save(),
            text: R.string.localizable.save()
        ) { button in
            button.addTarget(self, action: #selector(savePhoto(_:)), for: .touchUpInside)
        }
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func sendToMixinContact(_ sender: Any) {
        presentingViewController?.dismiss(animated: true) {
            self.contentViewController.shareToMixinContact()
        }
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func shareAsActivity(_ sender: Any) {
        contentViewController.shareAsActivity()
    }
    
    @objc private func copyLink(_ sender: Any) {
        contentViewController.copyLink()
    }
    
    @objc private func savePhoto(_ sender: Any) {
        contentViewController.savePhoto()
    }
    
    private func updatePreferredContentSizeHeight() {
        view.layoutIfNeeded()
        preferredContentSize.height = titleView.frame.height
        + contentWrapperView.frame.height
        + sendToContactBackgroundView.frame.height
        + actionTopConstraint.constant
        + actionHeightConstraint.constant
        + actionBottomConstraint.constant
        + max(20, view.safeAreaInsets.bottom)
    }
    
    private func addActionButton(
        icon: UIImage?,
        text: String,
        config additionalConfig: (UIButton) -> Void
    ) {
        var configuration: UIButton.Configuration = .plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0)
        configuration.background.imageContentMode = .top
        configuration.background.image = R.image.explore.action_tray()
        configuration.baseForegroundColor = R.color.text()
        configuration.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFont.preferredFont(forTextStyle: .caption1)
            return AttributedString(text, attributes: attributes)
        }()
        configuration.imagePlacement = .top
        configuration.imagePadding = 20
        configuration.image = icon?.withTintColor(R.color.text()!, renderingMode: .alwaysTemplate)
        let button = UIButton(configuration: configuration)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        additionalConfig(button)
        actionStackView.addArrangedSubview(button)
    }
    
}
