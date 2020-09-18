import UIKit
import SwiftyMarkdown
import MixinServices

class ExternalSharingConfirmationViewController: UIViewController {
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var previewWrapperView: UIView!
    
    private lazy var imageView = UIImageView()
    private lazy var label = UILabel()
    
    private var message: MessageItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backgroundView.layer.cornerRadius = 10
    }
    
    @IBAction func close(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    func load(context: ExternalSharingContext) {
        let item = MessageItem()
        item.messageId = UUID().uuidString.lowercased()
        item.userId = myUserId
        switch context.content {
        case .text(let text):
            item.category = MessageCategory.SIGNAL_TEXT.rawValue
            item.content = text
            loadPreview(forTextMessageWith: text)
        case .image(let url):
            item.category = MessageCategory.SIGNAL_IMAGE.rawValue
            loadPreview(forImageWith: url)
        case .live(let data):
            item.category = MessageCategory.SIGNAL_LIVE.rawValue
            item.mediaUrl = data.url
            item.mediaWidth = data.width
            item.mediaHeight = data.height
            item.thumbUrl = data.thumbUrl
            loadPreview(for: data)
        case .contact(let data):
            item.category = MessageCategory.SIGNAL_CONTACT.rawValue
            item.sharedUserId = data.userId
            loadPreview(forContactWith: data.userId)
        case .post(let text):
            item.category = MessageCategory.SIGNAL_POST.rawValue
            item.content = text
            loadPreview(forPostMessageWith: text)
        case .appCard(let data):
            item.category = MessageCategory.APP_CARD.rawValue
            loadPreview(for: data)
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
    }
    
    private func loadPreview(forTextMessageWith text: String) {
        label.text = text
        placePreviewViewsAsTextMessage()
    }
    
    private func loadPreview(forImageWith url: URL) {
        imageView.contentMode = .scaleAspectFit
        imageView.sd_setImage(with: url, completed: nil)
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
        
        DispatchQueue.global().async { [weak avatarImageView, weak contentView] in
            guard let user = UserDAO.shared.getUser(userId: userId) else {
                return
            }
            DispatchQueue.main.async {
                guard let avatarImageView = avatarImageView, let contentView = contentView else {
                    return
                }
                avatarImageView.setImage(with: user)
                contentView.fullnameLabel.text = user.fullName
                contentView.idLabel.text = user.identityNumber
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
    }
    
}
