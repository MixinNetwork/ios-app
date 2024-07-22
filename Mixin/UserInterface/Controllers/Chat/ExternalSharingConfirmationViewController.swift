import UIKit
import WebKit
import SDWebImage
import MixinServices

class ExternalSharingConfirmationViewController: UIViewController {
    
    enum Action {
        case send(conversation: ConversationItem, ownerUser: UserItem)
        case forward
    }
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var previewWrapperView: UIView!
    @IBOutlet weak var sendButton: RoundedButton!
    
    private lazy var imageView = SDAnimatedImageView()
    private lazy var label = UILabel()
    
    private var sharingContext: ExternalSharingContext!
    private var message: Message!
    private var action: Action!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backgroundView.layer.cornerRadius = 10
    }
    
    @IBAction func close(_ sender: Any) {
        if let context = sharingContext, case let .image(photoUrl) = context.content {
            try? FileManager.default.removeItem(at: photoUrl)
        }
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func performAction(_ sender: Any) {
        guard var message = message else {
            return
        }
        switch action {
        case let .send(conversation, ownerUser):
            message.createdAt = Date().toUTCString()
            SendMessageService.shared.sendMessage(message: message, ownerUser: ownerUser, isGroupMessage: conversation.isGroup())
            showAutoHiddenHud(style: .notification, text: R.string.localizable.message_sent())
            dismiss(animated: true, completion: nil)
        case .forward:
            dismiss(animated: true) {
                let vc = MessageReceiverViewController.instance(content: .message(message))
                UIApplication.homeNavigationController?.pushViewController(vc, animated: true)
            }
        case .none:
            break
        }
    }
    
    func load(sharingContext: ExternalSharingContext, message: Message, webContext: MixinWebViewController.Context?, action: Action) {
        self.sharingContext = sharingContext
        self.message = message
        self.action = action
        
        switch sharingContext.content {
        case .text(let text):
            loadPreview(forTextMessageWith: text)
        case .image(let url):
            loadPreview(forImageWith: url)
        case .live(let data):
            loadPreview(for: data)
        case .contact(let data):
            loadPreview(forContactWith: data.userId)
        case .post(let text):
            loadPreview(forPostMessageWith: text)
        case .appCard(let data):
            loadPreview(for: data)
        case .sticker(let id, let isAdded):
            loadStickerPreview(stickerId: id, isAdded: isAdded ?? false)
        }
        
        let localizedContentCategory = sharingContext.content.localizedCategory
        if let context = webContext {
            switch context.style {
            case let .app(app, _):
                let source = "\(app.name)(\(app.appNumber))"
                titleLabel.text = R.string.localizable.share_message_description(source, localizedContentCategory)
            case .webPage:
                if let source = context.initialUrl.host {
                    titleLabel.text = R.string.localizable.share_message_description(source, localizedContentCategory)
                } else {
                    titleLabel.text = R.string.localizable.share_message_description_empty(localizedContentCategory)
                }
            }
        } else {
            titleLabel.text = R.string.localizable.share_message_description_empty(localizedContentCategory)
        }
        
        switch action {
        case .forward:
            sendButton.setTitle(R.string.localizable.forward(), for: .normal)
        case .send:
            sendButton.setTitle(R.string.localizable.send(), for: .normal)
        }
    }
    
}

extension ExternalSharingConfirmationViewController {
    
    private func loadPreview(forTextMessageWith text: String) {
        label.text = text
        label.setFont(scaledFor: .systemFont(ofSize: 16), adjustForContentSize: true)
        label.textColor = R.color.text()
        label.numberOfLines = 10
        previewWrapperView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(40)
            make.trailing.lessThanOrEqualToSuperview().offset(-40)
        }
        
        imageView.image = R.image.ic_chat_bubble_right_white()
        previewWrapperView.insertSubview(imageView, belowSubview: label)
        imageView.snp.makeConstraints { (make) in
            let inset = UIEdgeInsets(top: -9, left: -10, bottom: -11, right: -17)
            make.edges.equalTo(label).inset(inset)
        }
        
        sendButton.isEnabled = true
    }
    
    private func loadPreview(forImageWith url: URL) {
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = previewWrapperView.layer.cornerRadius
        imageView.clipsToBounds = true
        imageView.sd_setImage(with: url)
        previewWrapperView.addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            let inset = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
            make.edges.equalToSuperview().inset(inset)
        }
        sendButton.isEnabled = true
    }
    
    private func loadPreview(for liveData: TransferLiveData) {
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        previewWrapperView.addSubview(imageView)
        
        let ratio: CGFloat
        if liveData.width < 1 || liveData.height < 1 {
            ratio = 1
        } else {
            ratio = CGFloat(liveData.width) / CGFloat(liveData.height)
        }
        imageView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.width.equalTo(imageView.snp.height).multipliedBy(ratio)
            make.leading.top.greaterThanOrEqualToSuperview().offset(36)
            make.trailing.bottom.lessThanOrEqualToSuperview().offset(-36)
        }
        if let url = URL(string: liveData.thumbUrl) {
            imageView.sd_setImage(with: url, completed: nil)
        }
        
        let badgeView = UIImageView(image: R.image.live_badge())
        previewWrapperView.addSubview(badgeView)
        badgeView.snp.makeConstraints { (make) in
            make.top.equalTo(imageView).offset(4)
            make.leading.equalTo(imageView).offset(9)
        }
        
        sendButton.isEnabled = true
    }
    
    private func loadPreview(forContactWith userId: String) {
        let cardView = UIView()
        previewWrapperView.addSubview(cardView)
        cardView.snp.makeConstraints { (make) in
            make.leading.greaterThanOrEqualToSuperview().offset(30)
            make.trailing.lessThanOrEqualToSuperview().offset(-30)
            make.center.equalToSuperview()
        }
        
        imageView.image = R.image.ic_chat_bubble_right_white()
        imageView.setContentHuggingPriority(.almostInexist, for: .horizontal)
        imageView.setContentHuggingPriority(.almostInexist, for: .vertical)
        cardView.addSubview(imageView)
        imageView.snp.makeEdgesEqualToSuperview()
        
        let avatarImageView = AvatarImageView()
        cardView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.width.height.equalTo(40)
            make.leading.equalToSuperview().offset(12)
        }
        
        let contentView = ContactMessageCellRightView()
        cardView.addSubview(contentView)
        contentView.snp.makeConstraints { (make) in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(8)
            make.top.equalToSuperview().offset(13)
            make.bottom.equalToSuperview().offset(-15)
            make.trailing.equalToSuperview().offset(-41)
            make.centerY.equalTo(avatarImageView)
        }
        
        DispatchQueue.global().async { [weak avatarImageView, weak contentView, weak sendButton] in
            guard let user = UserDAO.shared.getUser(userId: userId) else {
                return
            }
            
            let badge: UIImage?
            if user.isVerified {
                badge = R.image.ic_user_verified()
            } else if user.isBot {
                badge = R.image.ic_user_bot()
            } else {
                badge = nil
            }
            
            DispatchQueue.main.async {
                guard let contentView = contentView else {
                    return
                }
                avatarImageView?.setImage(with: user)
                contentView.fullnameLabel.text = user.fullName
                contentView.idLabel.text = user.identityNumber
                if let badge = badge {
                    contentView.badgeImageView.image = badge
                    contentView.badgeImageView.isHidden = false
                } else {
                    contentView.badgeImageView.isHidden = true
                }
                sendButton?.isEnabled = true
            }
        }
    }
    
    private func loadPreview(forPostMessageWith text: String) {
        let maxNumberOfLines = 10
        var lines = [String]()
        text.enumerateLines { (line, stop) in
            lines.append(line)
            if lines.count == maxNumberOfLines {
                stop = true
            }
        }
        let string = lines.joined(separator: "\n")
        let html = MarkdownConverter.htmlString(from: string, richFormat: false)
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
        previewWrapperView.addSubview(webView)
        webView.snp.makeConstraints { (make) in
            let inset = UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40)
            make.edges.equalToSuperview().inset(inset)
        }
        
        imageView.image = R.image.ic_chat_bubble_right_white()
        previewWrapperView.insertSubview(imageView, belowSubview: webView)
        imageView.snp.makeConstraints { (make) in
            let inset = UIEdgeInsets(top: -9, left: -10, bottom: -11, right: -17)
            make.edges.equalTo(webView).inset(inset)
        }
        
        sendButton.isEnabled = true
        let postSuperscript = UIImageView(image: R.image.conversation.ic_message_expand())
        previewWrapperView.addSubview(postSuperscript)
        postSuperscript.snp.makeConstraints { (make) in
            make.top.equalTo(imageView).offset(5)
            make.trailing.equalTo(imageView).offset(-13)
        }
        
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(presentPostPreview))
        imageView.addGestureRecognizer(recognizer)
        imageView.isUserInteractionEnabled = true
        for view in [webView, postSuperscript] {
            view.isUserInteractionEnabled = false
        }
    }
    
    private func loadPreview(for appCardData: AppCardData) {
        switch appCardData {
        case .v0(let content):
            imageView.image = R.image.ic_chat_bubble_right_white()
            previewWrapperView.addSubview(imageView)
            imageView.snp.makeConstraints { (make) in
                make.leading.greaterThanOrEqualToSuperview().offset(30)
                make.trailing.lessThanOrEqualToSuperview().offset(-30)
                make.center.equalToSuperview()
            }
            
            let iconImageView = UIImageView()
            iconImageView.layer.cornerRadius = 5
            iconImageView.clipsToBounds = true
            imageView.addSubview(iconImageView)
            iconImageView.snp.makeConstraints { (make) in
                make.width.height.equalTo(40)
                make.leading.equalToSuperview().offset(12)
            }
            
            let contentView = CardMessageTitleView()
            contentView.titleLabel.textColor = .text
            contentView.titleLabel.font = MessageFontSet.cardTitle.scaled
            contentView.titleLabel.adjustsFontForContentSizeCategory = true
            contentView.subtitleLabel.textColor = R.color.text_tertiary()!
            contentView.subtitleLabel.font = MessageFontSet.cardSubtitle.scaled
            contentView.subtitleLabel.adjustsFontForContentSizeCategory = true
            imageView.addSubview(contentView)
            contentView.snp.makeConstraints { (make) in
                make.leading.equalTo(iconImageView.snp.trailing).offset(8)
                make.top.equalToSuperview().offset(13)
                make.bottom.equalToSuperview().offset(-15)
                make.trailing.equalToSuperview().offset(-41)
                make.centerY.equalTo(iconImageView)
            }
            
            iconImageView.sd_setImage(with: content.iconUrl, completed: nil)
            contentView.titleLabel.text = content.title
            contentView.subtitleLabel.text = content.description
            
            sendButton.isEnabled = true
        case .v1(let content):
            let contentView = UIView()
            previewWrapperView.addSubview(contentView)
            contentView.snp.makeConstraints { (make) in
                make.top.greaterThanOrEqualToSuperview().offset(35)
                make.centerY.equalToSuperview().priority(.high)
                make.leading.equalToSuperview().offset(35)
                make.trailing.equalToSuperview().offset(-35)
            }
            
            imageView.image = R.image.ic_chat_bubble_right_white()
            contentView.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                let insets = UIEdgeInsets(top: 0, left: -2, bottom: 0, right: -9)
                make.top.leading.trailing.equalToSuperview().inset(insets)
            }
            
            let cardContentView = AppCardV1MessageCell.CardContentView()
            contentView.addSubview(cardContentView)
            cardContentView.reloadData(with: content)
            cardContentView.snp.makeConstraints { (make) in
                let insets = UIEdgeInsets(top: 1, left: 2, bottom: 12, right: 8)
                make.edges.equalTo(imageView).inset(insets)
            }
            
            if !content.actions.isEmpty {
                final class ButtonsView: AppButtonGroupView {
                    
                    override var intrinsicContentSize: CGSize {
                        CGSize(width: lastLayoutWidth, height: buttonsViewModel.buttonGroupFrame.height)
                    }
                    
                    private let buttonsViewModel = AppButtonGroupViewModel()
                    private let actions: [AppCardData.V1Content.Action]
                    
                    private var lastLayoutWidth: CGFloat = 288
                    
                    init(actions: [AppCardData.V1Content.Action]) {
                        self.actions = actions
                        super.init(frame: .zero)
                        buttonsViewModel.layout(lineWidth: lastLayoutWidth,
                                                contents: actions.map(\.label))
                        layoutButtons(viewModel: buttonsViewModel)
                        for (i, action) in actions.enumerated() {
                            buttonViews[i].setTitle(action.label,
                                                    colorHexString: action.color,
                                                    disclosureIndicator: action.isActionExternal)
                        }
                    }
                    
                    required init?(coder: NSCoder) {
                        fatalError("Not supported")
                    }
                    
                    override func layoutSubviews() {
                        super.layoutSubviews()
                        if bounds.width != lastLayoutWidth {
                            buttonsViewModel.layout(lineWidth: bounds.width, contents: actions.map(\.label))
                            layoutButtons(viewModel: buttonsViewModel)
                            lastLayoutWidth = bounds.width
                            invalidateIntrinsicContentSize()
                        }
                    }
                    
                }
                let buttonsView = ButtonsView(actions: content.actions)
                buttonsView.isUserInteractionEnabled = false
                contentView.addSubview(buttonsView)
                buttonsView.snp.makeConstraints { make in
                    make.top.equalTo(imageView.snp.bottom)
                    make.leading.equalToSuperview().offset(-AppButtonView.buttonMargin.leading)
                    make.trailing.equalToSuperview().offset(AppButtonView.buttonMargin.trailing)
                    make.bottom.equalToSuperview()
                }
            }
            
            sendButton.isEnabled = true
        }
    }
    
    private func loadStickerPreview(stickerId: String, isAdded: Bool) {
        let stickerView = AnimatedStickerView()
        stickerView.autoPlayAnimatedImage = true
        previewWrapperView.addSubview(stickerView)
        stickerView.snp.makeConstraints { (make) in
            let inset = UIEdgeInsets(top: 70, left: 70, bottom: 70, right: 70)
            make.edges.equalToSuperview().inset(inset)
        }
        stickerView.load(url: message.mediaUrl, persistent: isAdded)
        sendButton.isEnabled = true
    }
    
    @objc private func presentPostPreview() {
        guard let message = message, message.category.hasSuffix("_POST") else {
            return
        }
        PostWebViewController.presentInstance(message: message, asChildOf: self)
    }
    
}
