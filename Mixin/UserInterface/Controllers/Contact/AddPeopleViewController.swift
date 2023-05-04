import UIKit
import MixinServices

class AddPeopleViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var myIdLabel: UILabel!
    @IBOutlet weak var searchButton: RoundedButton!
    
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private let legalKeywordCharactersSet = Set("+0123456789")
    private let phoneNumberValidator = PhoneNumberValidator()
    
    private var keywordTextField: UITextField {
        return searchBoxView.textField
    }
    
    private var keyword: String {
        return keywordTextField.text ?? ""
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let id = LoginManager.shared.account?.identityNumber {
            myIdLabel.text = R.string.localizable.my_mixin_id(id)
        }
        searchButton.isEnabled = false
        keywordTextField.keyboardType = .phonePad
        keywordTextField.placeholder = R.string.localizable.mixin_id_or_phone()
        keywordTextField.addTarget(self, action: #selector(checkKeywordAction), for: .editingChanged)
        keywordTextField.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !keywordTextField.isFirstResponder {
            keywordTextField.becomeFirstResponder()
        }
    }
    
    override func layout(for keyboardFrame: CGRect) {
        keyboardPlaceholderHeightConstraint.constant = view.frame.height - keyboardFrame.origin.y
        view.layoutIfNeeded()
    }
    
    @objc func checkKeywordAction(_ sender: Any) {
        let filteredKeyword = keyword.filter(legalKeywordCharactersSet.contains)
        keywordTextField.text = filteredKeyword
        searchButton.isEnabled = isLegalKeyword(filteredKeyword)
    }
    
    @IBAction func searchAction(_ sender: Any) {
        searchButton.isBusy = true
        UserAPI.search(keyword: keyword) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.searchButton.isBusy = false
            switch result {
            case let .success(user):
                UserDAO.shared.updateUsers(users: [user])
                let userItem = UserItem.createUser(from: user)
                let vc = UserProfileViewController(user: userItem)
                vc.updateUserFromRemoteAfterReloaded = false
                weakSelf.present(vc, animated: true, completion: nil)
            case let .failure(error):
                let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.user_not_found())
                showAutoHiddenHud(style: .error, text: text)
            }
        }
    }
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.contact.add_people()!
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.search_contacts())
    }
    
    private func isLegalKeyword(_ keyword: String) -> Bool {
        guard keyword.count >= 4 else {
            return false
        }
        if keyword.hasPrefix("+") {
            return phoneNumberValidator.isValid(keyword)
        } else {
            return true
        }
    }
    
}
