import UIKit
import MixinServices

class InviteLinkViewController: UIViewController {

    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var groupNameLabel: UILabel!
    @IBOutlet weak var linkLabel: UILabel!

    private var conversation: ConversationItem!
    private lazy var qrcodeWindow = QrcodeWindow.instance()
    
    private lazy var shareLinkController: UIActivityViewController? = {
        if let codeUrl = conversation.codeUrl {
            return UIActivityViewController(activityItems: [codeUrl], applicationActivities: nil)
        } else {
            return nil
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        iconImageView.setGroupImage(with: conversation.iconUrl)
        groupNameLabel.text = conversation.name
        updateUI()
    }

    private func updateUI() {
        linkLabel.text = conversation.codeUrl
    }
    
    @IBAction func shareLinkAction(_ sender: Any) {
        guard let shareLinkController = shareLinkController else {
            return
        }
        present(shareLinkController, animated: true, completion: nil)
    }
    
    @IBAction func copyLinkAction(_ sender: Any) {
        UIPasteboard.general.string = conversation.codeUrl
        showAutoHiddenHud(style: .notification, text: Localized.TOAST_COPIED)
    }
    
    @IBAction func qrCodeAction(_ sender: Any) {
        qrcodeWindow.render(conversation: conversation)
        qrcodeWindow.presentView()
    }
    
    class func instance(conversation: ConversationItem) -> UIViewController {
        let vc = R.storyboard.group.invite_link()!
        vc.conversation = conversation
        return ContainerViewController.instance(viewController: vc, title: Localized.GROUP_NAVIGATION_TITLE_INVITE_LINK)
    }
    
}

extension InviteLinkViewController: ContainerViewControllerDelegate {

    func barRightButtonTappedAction() {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.GROUP_BUTTON_TITLE_RESET_LINK, style: .default, handler: { [weak self] (_) in
            self?.revokeLink()
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }

    func imageBarRightButton() -> UIImage? {
        return R.image.ic_title_more()
    }

    private func revokeLink() {
        guard !(container?.rightButton.isBusy ?? true) else {
            return
        }

        container?.rightButton.isBusy = true
        ConversationAPI.shared.updateCodeId(conversationId: conversation.conversationId) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }

            weakSelf.container?.rightButton.isBusy = false
            switch result {
            case let .success(response):
                DispatchQueue.global().async {
                    ConversationDAO.shared.updateCodeUrl(conversation: response)
                    DispatchQueue.main.async {
                        weakSelf.conversation = ConversationItem(response: response)
                        weakSelf.updateUI()
                    }
                }
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }

}
