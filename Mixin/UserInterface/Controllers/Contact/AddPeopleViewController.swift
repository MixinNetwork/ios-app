import UIKit
import PhoneNumberKit

class AddPeopleViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var myIdLabel: UILabel!
    @IBOutlet weak var searchButton: RoundedButton!
    
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private let legalKeywordCharactersSet = Set("+0123456789")
    private let phoneNumberKit = PhoneNumberKit()
    
    private var keywordTextField: UITextField {
        return searchBoxView.textField
    }
    
    private var keyword: String {
        return keywordTextField.text ?? ""
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let id = Account.current?.identity_number {
            myIdLabel.text = Localized.CONTACT_MY_IDENTITY_NUMBER(id: id)
        }
        searchButton.isEnabled = false
        keywordTextField.keyboardType = .phonePad
        keywordTextField.placeholder = Localized.PLACEHOLDER_MIXIN_ID_OR_PHONE
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
                let userItem = UserItem.createUser(from: user)
                let vc = UserProfileViewController(user: userItem)
                vc.updateUserFromRemoteAfterReloaded = false
                weakSelf.present(vc, animated: true, completion: nil)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.code == 404 ? Localized.CONTACT_SEARCH_NOT_FOUND : error.localizedDescription)
            }
        }
    }
    
    class func instance() -> UIViewController {
        let vc = Storyboard.contact.instantiateViewController(withIdentifier: "add_people")
        return ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_ADD)
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
