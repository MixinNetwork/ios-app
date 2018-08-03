import UIKit
import PhoneNumberKit

class AddPeopleViewController: UIViewController {
    
    @IBOutlet weak var keywordTextField: UITextField!
    @IBOutlet weak var myIdLabel: UILabel!
    @IBOutlet weak var searchButtonWrapper: UIView!
    @IBOutlet weak var searchButton: StateResponsiveButton!
    
    @IBOutlet weak var searchButtonBottomConstraint: NSLayoutConstraint!
    
    private let legalKeywordCharactersSet = Set("+0123456789")
    private let phoneNumberKit = PhoneNumberKit()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let id = AccountAPI.shared.account?.identity_number {
            myIdLabel.text = Localized.CONTACT_MY_IDENTITY_NUMBER(id: id)
        }
        keywordTextField.becomeFirstResponder()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: .UIKeyboardWillChangeFrame, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func checkKeywordAction(_ sender: Any) {
        let filteredKeyword = String(keyword.filter(legalKeywordCharactersSet.contains))
        keywordTextField.text = filteredKeyword
        searchButtonWrapper.isHidden = !isLegalKeyword(filteredKeyword)
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
                UserWindow.instance().updateUser(user: UserItem.createUser(from: user), refreshUser: false).presentView()
            case let .failure(error):
                NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: error.code == 404 ? Localized.CONTACT_SEARCH_NOT_FOUND : error.localizedDescription)
            }
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        let endFrame: CGRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        let windowHeight = AppDelegate.current.window!.bounds.height
        searchButtonBottomConstraint.constant = windowHeight - endFrame.origin.y
    }
    
    class func instance() -> UIViewController {
        let vc = Storyboard.contact.instantiateViewController(withIdentifier: "add_people")
        return ContainerViewController.instance(viewController: vc, title: Localized.NAVIGATION_TITLE_ADD_PEOPLE)
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
