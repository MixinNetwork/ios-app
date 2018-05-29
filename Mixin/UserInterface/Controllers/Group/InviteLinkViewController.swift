import UIKit

class InviteLinkViewController: UIViewController {

    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var groupNameLabel: UILabel!
    @IBOutlet weak var linkLabel: UILabel!
    @IBOutlet weak var resetButton: StateResponsiveButton!

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

        iconImageView.setGroupImage(with: conversation.iconUrl, conversationId: conversation.conversationId)
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
        NotificationCenter.default.postOnMain(name: .ToastMessageDidAppear, object: Localized.TOAST_COPIED)
    }
    
    @IBAction func qrCodeAction(_ sender: Any) {
        let vc = QRCodeViewController.instance(content: .group(conversation))
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func revokeLinkAction(_ sender: Any) {
        guard !resetButton.isBusy else {
            return
        }

        resetButton.isBusy = true
        ConversationAPI.shared.updateCodeId(conversationId: conversation.conversationId) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.resetButton.isBusy = false
            switch result {
            case let .success(response):
                DispatchQueue.global().async {
                    ConversationDAO.shared.updateCodeUrl(conversation: response)
                    DispatchQueue.main.async {
                        weakSelf.conversation = ConversationItem.createConversation(from: response)
                        weakSelf.updateUI()
                    }
                }
            case .failure:
                break
            }
        }
    }
    
    class func instance(conversation: ConversationItem) -> UIViewController {
        let vc = Storyboard.group.instantiateViewController(withIdentifier: "invite_link") as! InviteLinkViewController
        vc.conversation = conversation
        return ContainerViewController.instance(viewController: vc, title: Localized.GROUP_NAVIGATION_TITLE_INVITE_LINK)
    }
    
}
