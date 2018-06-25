import UIKit
import CoreImage

class QRCodeViewController: UIViewController {

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var qrcodeAvatarImageView: AvatarImageView!
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var fullNameLabel: UILabel!
    @IBOutlet weak var identifyNumberLabel: UILabel!
    @IBOutlet weak var promptLabel: UILabel!

    enum Content {
        case me
        case group(ConversationItem)
    }
    
    private var content = Content.me
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layoutIfNeeded()
        qrcodeAvatarImageView.layer.borderColor = UIColor.white.cgColor
        qrcodeAvatarImageView.layer.borderWidth = 2
        switch content {
        case .me:
            if let account = AccountAPI.shared.account {
                qrcodeImageView.image = UIImage(qrcode: account.code_url, size: qrcodeImageView.frame.size)
                avatarImageView.setImage(with: account)
                qrcodeAvatarImageView.setImage(with: account)
                fullNameLabel.text = account.full_name
                identifyNumberLabel.text = Localized.PROFILE_MIXIN_ID(id: account.identity_number)
            }
            promptLabel.text = Localized.MYQRCODE_PROMPT
        case .group(let conversation):
            if let url = conversation.codeUrl {
                qrcodeImageView.image = UIImage(qrcode: url, size: qrcodeImageView.frame.size)
            }
            avatarImageView.setGroupImage(with: conversation.iconUrl, conversationId: conversation.conversationId)
            qrcodeAvatarImageView.setGroupImage(with: conversation.iconUrl, conversationId: conversation.conversationId)
            fullNameLabel.text = conversation.name
            identifyNumberLabel.text = ""
            promptLabel.text = Localized.GROUP_QR_CODE_PROMPT
        }
    }
    
    class func instance(content: Content) -> UIViewController {
        let vc = Storyboard.contact.instantiateViewController(withIdentifier: "my_qrcode") as! QRCodeViewController
        vc.content = content
        switch content {
        case .me:
            return ContainerViewController.instance(viewController: vc, title: Localized.MYQRCODE_TITLE)
        case .group:
            return ContainerViewController.instance(viewController: vc, title: Localized.GROUP_QR_CODE)
        }
    }
    
}
