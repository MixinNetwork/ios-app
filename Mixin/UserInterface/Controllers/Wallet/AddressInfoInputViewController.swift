import UIKit
import MixinServices

class AddressInfoInputViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var nextButton: StyledButton!
    
    @IBOutlet weak var stackViewBottomConstraint: NSLayoutConstraint!
    
    let token: TokenItem
    
    private(set) weak var cell: AddressInfoInputCell?
    
    init(token: TokenItem) {
        self.token = token
        let nib = R.nib.addressInfoInputView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.addressInfoInputCell)
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        nextButton.setTitle(R.string.localizable.next(), for: .normal)
        nextButton.style = .filled
        nextButton.applyDefaultContentInsets()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    override func layout(for keyboardFrame: CGRect) {
        stackViewBottomConstraint.constant = keyboardFrame.height
    }
    
    @IBAction func goNext(_ sender: Any) {
        
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        stackViewBottomConstraint.constant = 0
        view.layoutIfNeeded()
    }
    
}

extension AddressInfoInputViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension AddressInfoInputViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.address_info_input, for: indexPath)!
        cell.load(token: token)
        self.cell = cell
        return cell
    }
    
}

extension AddressInfoInputViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? AddressInfoInputCell {
            cell.textView.becomeFirstResponder()
        }
    }
    
}
