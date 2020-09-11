import UIKit
import MixinServices

class AnnouncementViewController: KeyboardBasedLayoutViewController {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var saveButton: RoundedButton!

    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!

    var newAnnouncement: String {
        return textView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    var announcement: String {
        return ""
    }

    convenience init() {
        self.init(nib: R.nib.announcementView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.layer.cornerRadius = 8
        textView.layer.masksToBounds = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.becomeFirstResponder()
        textView.delegate = self
        textView.text = announcement
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIView.performWithoutAnimation {
            // Workaround for view's layout issue
            // view.frame.origin here is {0, 0}
            view.layoutIfNeeded()
            // Now it becomes {0, v}
            // v is found to be (windowHeight - xibHeight) / 2
            view.frame.origin = .zero // Set it back to {0, 0}
        }
    }
    
    override func layout(for keyboardFrame: CGRect) {
        keyboardPlaceholderHeightConstraint.constant = view.frame.height - keyboardFrame.origin.y
        view.layoutIfNeeded()
    }

    @IBAction func saveAction(_ sender: Any) {
    }

    func saveFailedAction(error: MixinAPIError) {
        showAutoHiddenHud(style: .error, text: error.localizedDescription)
        saveButton.isBusy = false
        textView.isUserInteractionEnabled = true
        textView.becomeFirstResponder()
    }

    func saveSuccessAction() {
        showAutoHiddenHud(style: .notification, text: Localized.TOAST_SAVED)
        navigationController?.popViewController(animated: true)
    }

}

extension AnnouncementViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        guard let newAnnouncement = textView.text else {
            return
        }

        saveButton.isEnabled = !newAnnouncement.isEmpty && newAnnouncement != announcement
    }

}
