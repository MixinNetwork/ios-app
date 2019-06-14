import UIKit

class GroupAnnouncementViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var saveButton: RoundedButton!
    
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private var newAnnouncement: String {
        return textView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private var conversation: ConversationItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.layer.cornerRadius = 8
        textView.layer.masksToBounds = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.becomeFirstResponder()
        textView.delegate = self
        if let conversation = self.conversation {
            textView.text = conversation.announcement
        }
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let windowHeight = AppDelegate.current.window!.bounds.height
        keyboardPlaceholderHeightConstraint.constant = windowHeight - keyboardFrame.origin.y
        view.layoutIfNeeded()
    }
    
    @IBAction func saveAction(_ sender: Any) {
        guard !saveButton.isBusy else {
            return
        }
        saveButton.isBusy = true
        ConversationAPI.shared.updateGroupAnnouncement(conversationId: conversation.conversationId, announcement: newAnnouncement) { [weak self] (response) in
            switch response {
            case let .success(conversation):
                let change = ConversationChange(conversationId: conversation.conversationId, action: .updateConversation(conversation: conversation))
                NotificationCenter.default.post(name: .ConversationDidChange, object: change)
                showHud(style: .notification, text: Localized.TOAST_SAVED)
                self?.navigationController?.popViewController(animated: true)
            case let .failure(error):
                showHud(style: .error, text: error.localizedDescription)
                self?.saveButton.isBusy = false
                self?.textView.isUserInteractionEnabled = true
                self?.textView.becomeFirstResponder()
            }
        }
    }
    
    class func instance(conversation: ConversationItem) -> UIViewController {
        let vc = Storyboard.group.instantiateViewController(withIdentifier: "announcement") as! GroupAnnouncementViewController
        vc.conversation = conversation
        let container = ContainerViewController.instance(viewController: vc, title: Localized.GROUP_NAVIGATION_TITLE_ANNOUNCEMENT)
        return container
    }
    
}

extension GroupAnnouncementViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        guard let newAnnouncement = textView.text, let conversation = self.conversation else {
            return
        }

        saveButton.isEnabled = !newAnnouncement.isEmpty && newAnnouncement != conversation.announcement
    }

}
