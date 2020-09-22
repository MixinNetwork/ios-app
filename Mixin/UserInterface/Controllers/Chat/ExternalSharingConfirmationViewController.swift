import UIKit
import SwiftyMarkdown
import MixinServices

class ExternalSharingConfirmationViewController: UIViewController {
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var previewWrapperView: UIView!
    @IBOutlet weak var sendButton: RoundedButton!
    
    private lazy var imageView = UIImageView()
    private lazy var label = UILabel()
    
    private var message: Message?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backgroundView.layer.cornerRadius = 10
    }
    
    @IBAction func close(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func send(_ sender: Any) {
        guard var message = message else {
            return
        }
        message.createdAt = Date().toUTCString()
        if message.conversationId.isEmpty || message.conversationId != UIApplication.currentConversationId() {
            dismiss(animated: true) {
                let vc = MessageReceiverViewController.instance(content: .message(message))
                UIApplication.homeNavigationController?.pushViewController(vc, animated: true)
            }
        } else {
            sendButton.isBusy = true
            DispatchQueue.global().async {
                defer {
                    DispatchQueue.main.async {
                        self.dismiss(animated: true, completion: nil)
                    }
                }
                guard let conversation = ConversationDAO.shared.getConversation(conversationId: message.conversationId) else {
                    return
                }
                let user: UserItem?
                if conversation.ownerId.isEmpty {
                    user = nil
                } else {
                    user = UserDAO.shared.getUser(userId: conversation.ownerId)
                }
                SendMessageService.shared.sendMessage(message: message, ownerUser: user, isGroupMessage: conversation.isGroup())
            }
        }
    }
    
    func load(sharingContext: ExternalSharingContext, webContext: MixinWebViewController.Context?) {
        var message = Message.createMessage(messageId: UUID().uuidString.lowercased(),
                                            conversationId: sharingContext.conversationId ?? "",
                                            userId: myUserId,
                                            category: "",
                                            status: MessageStatus.SENDING.rawValue,
                                            createdAt: "")
        switch sharingContext.content {
        case .text(let text):
            message.category = MessageCategory.SIGNAL_TEXT.rawValue
            message.content = text
            loadPreview(forTextMessageWith: text)
        case .image(let url):
            message.category = MessageCategory.SIGNAL_IMAGE.rawValue
            message.mediaStatus = MediaStatus.PENDING.rawValue
            message.mediaUrl = url.absoluteString
            loadPreview(forImageWith: url)
        case .live(let data):
            message.category = MessageCategory.SIGNAL_LIVE.rawValue
            message.mediaUrl = data.url
            message.mediaWidth = data.width
            message.mediaHeight = data.height
            message.thumbUrl = data.thumbUrl
            loadPreview(for: data)
        case .contact(let data):
            message.category = MessageCategory.SIGNAL_CONTACT.rawValue
            message.sharedUserId = data.userId
            message.content = try! JSONEncoder.default.encode(data).base64EncodedString()
            loadPreview(forContactWith: data.userId)
        case .post(let text):
            message.category = MessageCategory.SIGNAL_POST.rawValue
            message.content = text
            loadPreview(forPostMessageWith: text)
        case .appCard(let data):
            message.category = MessageCategory.APP_CARD.rawValue
            message.content = try! JSONEncoder.default.encode(data).base64EncodedString()
            loadPreview(for: data)
        }
        self.message = message
        
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
    
    private func placePreviewViewsAsTextMessage() {
        label.setFont(scaledFor: .systemFont(ofSize: 16), adjustForContentSize: true)
        label.textColor = R.color.text()
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
    
    private func loadPreview(forTextMessageWith text: String) {
        label.text = text
        placePreviewViewsAsTextMessage()
    }
    
    private func loadPreview(forImageWith url: URL) {
        imageView.contentMode = .scaleAspectFit
        imageView.sd_setImage(with: url) { [weak self] (image, _, _, _) in
            guard let self = self, let image = image else {
                return
            }
            self.message?.mediaWidth = Int(image.size.width)
            self.message?.mediaHeight = Int(image.size.height)
            self.sendButton.isEnabled = true
        }
        previewWrapperView.addSubview(imageView)
        imageView.snp.makeEdgesEqualToSuperview()
    }
    
    private func loadPreview(for liveData: TransferLiveData) {
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        previewWrapperView.addSubview(imageView)
        let ratio = CGFloat(liveData.width) / CGFloat(liveData.height)
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
        
        let playButton = ModernNetworkOperationButton(type: .custom)
        playButton.style = .finished(showPlayIcon: true)
        playButton.sizeToFit()
        playButton.isUserInteractionEnabled = false
        previewWrapperView.addSubview(playButton)
        playButton.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
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
        let md = SwiftyMarkdown(string: string)
        md.link.color = .theme
        let size = Counter(value: 15)
        for style in [md.body, md.h6, md.h5, md.h4, md.h3, md.h2, md.h1] {
            style.fontSize = CGFloat(size.advancedValue)
        }
        label.numberOfLines = maxNumberOfLines
        label.attributedText = md.attributedString()
        placePreviewViewsAsTextMessage()
        
        let postSuperscript = UIImageView(image: R.image.conversation.ic_message_expand())
        previewWrapperView.addSubview(postSuperscript)
        postSuperscript.snp.makeConstraints { (make) in
            make.top.equalTo(imageView).offset(5)
            make.trailing.equalTo(imageView).offset(-13)
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
    
}
