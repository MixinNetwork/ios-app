import UIKit
import PhoneNumberKit

class AddPeopleViewController: UIViewController {
    
    @IBOutlet weak var keywordTextField: UITextField!
    @IBOutlet weak var myIdLabel: UILabel!
    @IBOutlet weak var searchButton: RoundedButton!
    
    @IBOutlet weak var searchButtonBottomConstraint: NSLayoutConstraint!
    
    private let legalKeywordCharactersSet = Set("+0123456789")
    private let phoneNumberKit = PhoneNumberKit()
    private var userWindow = UserWindow.instance()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let id = AccountAPI.shared.account?.identity_number {
            myIdLabel.text = Localized.CONTACT_MY_IDENTITY_NUMBER(id: id)
        }
        userWindow.setDismissCallback { [weak self] in
            self?.keywordTextField.becomeFirstResponder()
        }
        searchButton.isEnabled = false
        keywordTextField.becomeFirstResponder()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func checkKeywordAction(_ sender: Any) {
        let filteredKeyword = String(keyword.filter(legalKeywordCharactersSet.contains))
        keywordTextField.text = filteredKeyword
        searchButton.isEnabled = isLegalKeyword(filteredKeyword)
    }
    
    @IBAction func searchAction(_ sender: Any) {
        searchButton.isBusy = true
        UserAPI.shared.search(keyword: keyword) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.searchButton.isBusy = false
            switch result {
            case let .success(user):
                UserDAO.shared.updateUsers(users: [user])
                weakSelf.userWindow.updateUser(user: UserItem.createUser(from: user), refreshUser: false).presentView()
            case let .failure(error):
                weakSelf.navigationController?.showHud(style: .error, text: error.code == 404 ? Localized.CONTACT_SEARCH_NOT_FOUND : error.localizedDescription)
            }
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        let endFrame: CGRect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        let windowHeight = AppDelegate.current.window!.bounds.height
        self.searchButtonBottomConstraint.constant = windowHeight - endFrame.origin.y + 20
        UIView.animate(withDuration: 0.15) {
            self.view.layoutIfNeeded()
        }
    }
    
    class func instance() -> UIViewController {
        let vc = Storyboard.contact.instantiateViewController(withIdentifier: "add_people")
        return ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_ADD)
    }
    
    private var keyword: String {
        return keywordTextField.text ?? ""
    }
    
    private func isLegalKeyword(_ keyword: String) -> Bool {
        guard keyword.count >= 4 else {
            return false
        }
        if keyword.hasPrefix("+") {
            return (try? phoneNumberKit.parse(keyword)) != nil
        } else {
            return true
        }
    }
    
}
