import UIKit

class MyProfileViewController: UITableViewController {

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var avatarUploadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var fullnameLabel: UILabel!
    @IBOutlet weak var changeFullnameIndicator: UIActivityIndicatorView!
    @IBOutlet weak var phoneNumberLabel: UILabel!

    private lazy var avatarPicker = ImagePickerController(initialCameraPosition: .front, cropImageAfterPicked: true, parent: self)
    private lazy var changeNameController: UIAlertController = {
        let vc = alertInput(title: Localized.CONTACT_TITLE_CHANGE_NAME, placeholder: Localized.PLACEHOLDER_NEW_NAME, handler: { [weak self](_) in
            self?.changeName()
        })
        vc.textFields?.first?.addTarget(self, action: #selector(checkNewName(_:)), for: .editingChanged)
        vc.actions[1].isEnabled = false
        return vc
    }()
    private var newName: String {
        return changeNameController.textFields?.first?.text ?? ""
    }
    private var uploadingAvatarInProgress: Bool {
        return avatarImageView.isHidden
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        updateUI()
        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: .AccountDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func checkNewName(_ sender: Any) {
        changeNameController.actions[1].isEnabled = !newName.isEmpty
    }

    @objc func updateUI() {
        DispatchQueue.main.async { [weak self] in
            guard let weakSelf = self, let account = AccountAPI.shared.account else {
                return
            }
            weakSelf.avatarImageView.setImage(with: account)
            weakSelf.fullnameLabel.text = account.full_name
            weakSelf.phoneNumberLabel.text = account.phone
            weakSelf.tableView.reloadData()
        }
    }
    
    private func changeName() {
        changeFullnameIndicator.startAnimating()
        fullnameLabel.isHidden = true
        AccountAPI.shared.update(fullName: newName) { [weak self] (result) in
            if let weakSelf = self {
                weakSelf.changeFullnameIndicator.stopAnimating()
                weakSelf.fullnameLabel.isHidden = false
            }
            switch result {
            case let .success(account):
                AccountAPI.shared.account = account
                DispatchQueue.global().async {
                    UserDAO.shared.updateAccount(account: account)
                }
            case .failure:
                break
            }
        }
    }

    class func instance() -> UIViewController {
        return ContainerViewController.instance(viewController: Storyboard.contact.instantiateViewController(withIdentifier: "my_profile"), title: Localized.CONTACT_PROFILE_TITLE)
    }
}

extension MyProfileViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                if !uploadingAvatarInProgress {
                    avatarPicker.viewController = self
                    avatarPicker.present()
                }
            case 1:
                if let account = AccountAPI.shared.account {
                    changeNameController.textFields?[0].text = account.full_name
                    present(changeNameController, animated: true, completion: nil)
                }
            default:
                break
            }
        case 1:
            let controller = UIAlertController(title: nil, message: Localized.PROFILE_CHANGE_NUMBER_CONFIRMATION, preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
            controller.addAction(UIAlertAction(title: Localized.PROFILE_CHANGE_NUMBER, style: .default, handler: { [weak self] (_) in
                self?.present(ChangeNumberNavigationController.instance(), animated: true, completion: nil)
            }))
            present(controller, animated: true, completion: nil)
        default:
            break
        }
    }
}

extension MyProfileViewController: ImagePickerControllerDelegate {
    
    func imagePickerController(_ controller: ImagePickerController, didPickImage image: UIImage) {
        avatarImageView.isHidden = true
        avatarUploadingIndicator.startAnimating()
        if let avatarBase64 = image.scaledToSize(newSize: CGSize(width: 1024, height: 1024)).base64 {
            AccountAPI.shared.update(fullName: nil, avatarBase64: avatarBase64, completion: { [weak self] (result) in
                if let weakSelf = self {
                    weakSelf.avatarImageView.isHidden = false
                    weakSelf.avatarUploadingIndicator.stopAnimating()
                }
                switch result {
                case let .success(account):
                    AccountAPI.shared.account = account
                    DispatchQueue.global().async {
                        UserDAO.shared.updateAccount(account: account)
                    }
                case .failure:
                    break
                }
            })
        } else {
            self.alert(Localized.CONTACT_ERROR_COMPOSE_AVATAR)
        }
    }
    
}

