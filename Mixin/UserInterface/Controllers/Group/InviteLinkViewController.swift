import UIKit
import MixinServices

class InviteLinkViewController: UIViewController {

    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var groupNameLabel: UILabel!
    @IBOutlet weak var linkLabel: UILabel!

    private var conversation: ConversationItem!
    
    private lazy var shareLinkController: UIActivityViewController? = {
        if let codeUrl = conversation.codeUrl {
            return UIActivityViewController(activityItems: [codeUrl], applicationActivities: nil)
        } else {
            return nil
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.invite_to_group_via_link()
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_title_more(),
            target: self,
            action: #selector(confirmRevokeLink(_:))
        )
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
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
    @IBAction func qrCodeAction(_ sender: Any) {
        guard let conversation, let code = conversation.codeUrl else {
            return
        }
        let qrCode = QRCodeViewController(title: conversation.name,
                                          content: code,
                                          foregroundColor: .black,
                                          description: R.string.localizable.group_qr_code_prompt(),
                                          centerContent: .avatar({ $0.setGroupImage(conversation: conversation) }))
        present(qrCode, animated: true)
    }
    
    class func instance(conversation: ConversationItem) -> UIViewController {
        let vc = R.storyboard.group.invite_link()!
        vc.conversation = conversation
        return vc
    }
    
    @objc private func confirmRevokeLink(_ button: BusyButton) {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: R.string.localizable.reset_link(), style: .default, handler: { [weak self] (_) in
            self?.revokeLink(button: button)
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
    private func revokeLink(button: BusyButton) {
        guard !button.isBusy else {
            return
        }
        button.isBusy = true
        ConversationAPI.updateCodeId(conversationId: conversation.conversationId) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            button.isBusy = false
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
