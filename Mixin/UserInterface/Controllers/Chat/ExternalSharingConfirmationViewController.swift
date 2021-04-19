import UIKit
import WebKit
import YYImage
import MixinServices

class ExternalSharingConfirmationViewController: UIViewController {
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var previewWrapperView: UIView!
    @IBOutlet weak var sendButton: RoundedButton!
    
    private lazy var imageView = YYAnimatedImageView()
    private lazy var label = UILabel()
    
    private var sharingContext: ExternalSharingContext!
    private var message: Message!
    private var conversation: ConversationItem!
    private var ownerUser: UserItem?
    
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
    
    @IBAction func send(_ sender: Any) {
        guard var message = message, conversation != nil else {
            return
        }
        message.createdAt = Date().toUTCString()
        SendMessageService.shared.sendMessage(message: message, ownerUser: ownerUser, isGroupMessage: conversation.isGroup())
        showAutoHiddenHud(style: .notification, text: R.string.localizable.chat_message_sent())
        dismiss(animated: true, completion: nil)
    }
    
    func load(sharingContext: ExternalSharingContext, message: Message, conversation: ConversationItem, ownerUser: UserItem?, webContext: MixinWebViewController.Context?) {
        self.sharingContext = sharingContext
        self.message = message
        self.conversation = conversation
        self.ownerUser = ownerUser
        
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
        }
        
        let localizedContentCategory = sharingContext.content.localizedCategory
        if let context = webContext {
            switch context.style {
            case let .app(app, _):
                let source = "\(app.name)(\(app.appNumber))"
                titleLabel.text = R.string.localizable.chat_external_sharing_title_from_source(source, localizedContentCategory)
            case .webPage:
                if let source = context.initialUrl.host {
                    titleLabel.text = R.string.localizable.chat_external_sharing_title_from_source(source, localizedContentCategory)
                } else {
                    titleLabel.text = R.string.localizable.chat_external_sharing_title_no_source(localizedContentCategory)
                }
            }
        } else {
            titleLabel.text = R.string.localizable.chat_external_sharing_title_no_source(localizedContentCategory)
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
        contentView.titleLabel.font = AppCardMessageViewModel.titleFontSet.scaled
        contentView.titleLabel.adjustsFontForContentSizeCategory = true
        contentView.subtitleLabel.textColor = .accessoryText
        contentView.subtitleLabel.font = AppCardMessageViewModel.descriptionFontSet.scaled
        contentView.subtitleLabel.adjustsFontForContentSizeCategory = true
        imageView.addSubview(contentView)
        contentView.snp.makeConstraints { (make) in
            make.leading.equalTo(iconImageView.snp.trailing).offset(8)
            make.top.equalToSuperview().offset(13)
            make.bottom.equalToSuperview().offset(-15)
            make.trailing.equalToSuperview().offset(-41)
            make.centerY.equalTo(iconImageView)
        }
        
        iconImageView.sd_setImage(with: appCardData.iconUrl, completed: nil)
        contentView.titleLabel.text = appCardData.title
        contentView.subtitleLabel.text = appCardData.description
        
        sendButton.isEnabled = true
    }
    
    @objc private func presentPostPreview() {
        guard let message = message, message.category == MessageCategory.SIGNAL_POST.rawValue else {
            return
        }
        PostWebViewController.presentInstance(message: message, asChildOf: self)
    }
    
}
