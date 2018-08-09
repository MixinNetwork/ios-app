import UIKit

class GroupAnnouncementViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var textViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private var newAnnouncement: String {
        return textView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private var conversation: ConversationItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let padding = textView.textContainer.lineFragmentPadding
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12 - padding, bottom: 12, right: 12 - padding)
        textView.delegate = self
        textView.becomeFirstResponder()
        container?.rightButton.isEnabled = true
        container?.rightButton.setTitleColor(.systemTint, for: .normal)
        if let conversation = conversation {
            textView.text = conversation.announcement
        }
        view.layoutIfNeeded()
        updateTextViewHeight()
        textView.contentOffset.y = max(0, (textViewHeightConstraint.constant - textView.bounds.height))
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: .UIKeyboardWillChangeFrame, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        let endFrame: CGRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        keyboardPlaceholderHeightConstraint.constant = endFrame.height
        CATransaction.performWithoutAnimation {
            view.layoutIfNeeded()
        }
    }
    
    class func instance(conversation: ConversationItem) -> UIViewController {
        let vc = Storyboard.group.instantiateViewController(withIdentifier: "announcement") as! GroupAnnouncementViewController
        vc.conversation = conversation
        let container = ContainerViewController.instance(viewController: vc, title: Localized.GROUP_NAVIGATION_TITLE_ANNOUNCEMENT)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
    
}

extension GroupAnnouncementViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        guard let actionButton = container?.rightButton, !actionButton.isBusy else {
            return
        }
        textView.isUserInteractionEnabled = false
        actionButton.isBusy = true
        ConversationAPI.shared.updateGroupAnnouncement(conversationId: conversation.conversationId, announcement: newAnnouncement) { [weak self] (response) in
            switch response {
            case let .success(conversation):
                let change = ConversationChange(conversationId: conversation.conversationId, action: .updateConversation(conversation: conversation))
                NotificationCenter.default.post(name: .ConversationDidChange, object: change)
                self?.navigationController?.popViewController(animated: true)
            case .failure:
                if let weakSelf = self {
                    weakSelf.container?.rightButton.isBusy = false
                    weakSelf.textView.isUserInteractionEnabled = true
                    weakSelf.textView.becomeFirstResponder()
                }
            }
        }
    }
    
    func textBarRightButton() -> String? {
        return Localized.ACTION_SAVE
    }
    
}

extension GroupAnnouncementViewController: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        updateTextViewHeight()
    }
    
}

extension GroupAnnouncementViewController {
    
    private func updateTextViewHeight() {
        let sizeToFit = CGSize(width: textView.bounds.width, height: UILayoutFittingExpandedSize.height)
        let height = textView.sizeThatFits(sizeToFit).height
        textViewHeightConstraint.constant = height
        view.layoutIfNeeded()
        textView.isScrollEnabled = textView.bounds.height < height
    }
    
}
