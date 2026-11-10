import UIKit
import MixinServices

protocol ModernShareContentViewController: UIViewController {
    func shareAsActivity()
    func copyLink()
    func savePhoto()
    func shareToMixinContact() async throws
}

final class PopupShareViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var contentWrapperView: UIView!
    @IBOutlet weak var sendToContactBackgroundView: UIView!
    @IBOutlet weak var sendToContactTitleLabel: UILabel!
    @IBOutlet weak var sendToContactContentLabel: UILabel!
    @IBOutlet weak var actionStackView: UIStackView!
    
    @IBOutlet weak var contentWrapperBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var actionTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var actionHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var actionBottomConstraint: NSLayoutConstraint!
    
    private let contentViewController: any ModernShareContentViewController
    private let rebating: String?
    
    private var sharingTask: Task<Void, Never>?
    private var sharingHUD: Hud?
    
    init<ContentViewController: ModernShareContentViewController>(
        contentViewController: ContentViewController,
        rebatingCode: Referral.RebatingCode?,
    ) {
        self.contentViewController = contentViewController
        self.rebating = if let rebate = rebatingCode?.rebate {
            PercentageFormatter.string(from: rebate, format: .precision, sign: .never)
        } else {
            nil
        }
        let nib = R.nib.popupShareView
        super.init(nibName: nib.name, bundle: nib.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleView.layer.cornerRadius = 13
        titleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        titleView.layer.masksToBounds = true
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
        sendToContactTitleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        sendToContactTitleLabel.text = R.string.localizable.perps_share_to_mixin_contact()
        if let rebating {
            let content = NSMutableAttributedString(
                string: R.string.localizable.perps_share_mixin_contact_desc_with_percent(rebating),
                attributes: [.foregroundColor: R.color.text_tertiary()!]
            )
            let rebatingRange = (content.string as NSString).range(of: rebating)
            content.setAttributes(
                [.foregroundColor: R.color.referral_rebating()!],
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
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sharingTask?.cancel()
        sharingHUD?.hide()
    }
    
    @IBAction func sendToMixinContact(_ sender: Any) {
        guard sharingTask == nil else {
            return
        }
        sharingTask = Task { [weak self] in
            guard let self else {
                return
            }
            let hud = Hud()
            sharingHUD = hud
            hud.show(style: .busy, text: "")
            view.isUserInteractionEnabled = false
            defer {
                hud.hide()
                sharingHUD = nil
                sharingTask = nil
                view.isUserInteractionEnabled = true
            }
            do {
                try await contentViewController.shareToMixinContact()
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                hud.hide()
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func shareAsActivity(_ sender: Any) {
        guard sharingTask == nil else {
            return
        }
        contentViewController.shareAsActivity()
    }
    
    @objc private func copyLink(_ sender: Any) {
        guard sharingTask == nil else {
            return
        }
        contentViewController.copyLink()
    }
    
    @objc private func savePhoto(_ sender: Any) {
        guard sharingTask == nil else {
            return
        }
        contentViewController.savePhoto()
    }
    
    private func updatePreferredContentSizeHeight() {
        let fittingSize = CGSize(
            width: view.bounds.width,
            height: UIView.layoutFittingExpandedSize.height
        )
        preferredContentSize.height = titleView.frame.height
        + contentWrapperView.systemLayoutSizeFitting(fittingSize).height
        + contentWrapperBottomConstraint.constant
        + sendToContactBackgroundView.systemLayoutSizeFitting(fittingSize).height
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
        
        if let imageView = button.imageView {
            let trayView = UIView()
            trayView.backgroundColor = R.color.background()
            trayView.layer.cornerRadius = 24
            trayView.layer.masksToBounds = true
            view.insertSubview(trayView, belowSubview: actionStackView)
            trayView.snp.makeConstraints { make in
                make.center.equalTo(imageView)
                make.width.height.equalTo(48)
            }
        }
    }
    
}

extension ModernShareContentViewController {
    
    func presentShareConfirmation(content: AppCardData.V1Content) throws {
        let cardData: AppCardData = .v1(content)
        var message = Message.createMessage(
            messageId: UUID().uuidString.lowercased(),
            conversationId: "",
            userId: myUserId,
            category: MessageCategory.APP_CARD.rawValue,
            status: MessageStatus.SENDING.rawValue,
            createdAt: Date().toUTCString()
        )
        message.content = try JSONEncoder.default.encode(cardData).base64EncodedString()
        let confirmation = ExternalSharingConfirmationViewController(
            sharingContext: ExternalSharingContext(content: .appCard(cardData)),
            message: message,
            webContext: nil,
            action: .forward
        )
        presentingViewController?.dismiss(animated: true) {
            UIApplication.shared.homeContainerViewController?.present(confirmation, animated: true)
        }
    }
    
}
