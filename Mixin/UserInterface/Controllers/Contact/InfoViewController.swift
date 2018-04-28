import UIKit

class InfoViewController: UITableViewController {

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var fullnameLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var aliasNameEditButton: StateResponsiveButton!
    @IBOutlet weak var muteLabel: UILabel!
    @IBOutlet weak var muteDetailLabel: UILabel!
    @IBOutlet weak var mutingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var addOrUnblockLoadingView: UIActivityIndicatorView!
    @IBOutlet weak var addOrUnblockLabel: UILabel!
    @IBOutlet weak var removeOrBlockLabel: UILabel!
    @IBOutlet weak var removeOrBlockLoadingView: UIActivityIndicatorView!
    @IBOutlet weak var verifiedImageView: UIImageView!
    
    private lazy var editAliasNameController: UIAlertController = {
        let vc = alertInput(title: Localized.PROFILE_EDIT_NAME, placeholder: Localized.PROFILE_FULL_NAME, handler: { [weak self](_) in
            self?.saveAliasNameAction()
        })
        vc.textFields?.first?.addTarget(self, action: #selector(alertInputChangedAction(_:)), for: .editingChanged)
        return vc
    }()

    private var userId = ""
    private var userAvatar = ""
    private var identityNumber = ""
    private var fullName = ""
    private var reputation = 0
    private var user: UserItem?
    private var muteRequestInProgress = false {
        didSet {
            if muteRequestInProgress {
                muteDetailLabel.isHidden = true
                mutingIndicator.startAnimating()
            } else {
                muteDetailLabel.isHidden = false
                mutingIndicator.stopAnimating()
            }
        }
    }
    
    private lazy var muteDurationController: UIAlertController = {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_8H, style: .default, handler: { [weak self](alert) in
            self?.muteUserAction(muteIntervalInSeconds: muteDuration8H)
        }))
        alert.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_1WEEK, style: .default, handler: { [weak self](alert) in
            self?.muteUserAction(muteIntervalInSeconds: muteDuration1Week)
        }))
        alert.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_1YEAR, style: .default, handler: { [weak self](alert) in
            self?.muteUserAction(muteIntervalInSeconds: muteDuration1Year)
        }))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        return alert
    }()
    
    private lazy var unmuteController: UIAlertController = {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.PROFILE_UNMUTE, style: .default, handler: { [weak self](alert) in
            self?.muteUserAction(muteIntervalInSeconds: 0)
        }))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        return alert
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        fetchProfile()
    }

    @IBAction func editAliasNameAction(_ sender: Any) {
        guard let user = self.user else {
            return
        }
        editAliasNameController.textFields?.first?.text = user.fullName
        present(editAliasNameController, animated: true, completion: nil)
    }

    @objc func alertInputChangedAction(_ sender: Any) {
        guard let text = editAliasNameController.textFields?.first?.text else {
            return
        }
        editAliasNameController.actions[1].isEnabled = !text.isEmpty
    }

    private func saveAliasNameAction() {
        guard let aliasName = editAliasNameController.textFields?.first?.text, !aliasName.isEmpty, let user = self.user  else {
            return
        }
        aliasNameEditButton.isBusy = true
        UserAPI.shared.remarkFriend(userId: user.userId, full_name: aliasName) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.aliasNameEditButton.isBusy = false
            weakSelf.handlerUpdateUser(result)
        }
    }

    private func fetchProfile() {
        let userId = self.userId
        guard !userId.isEmpty else {
            return
        }

        renderUser()
        if user == nil {
            DispatchQueue.global().async { [weak self] in
                let user = UserDAO.shared.getUser(userId: userId)
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.user = user
                    weakSelf.renderUser()
                    weakSelf.tableView.reloadData()
                    weakSelf.fetchUser(userId: userId)
                }
            }
        } else {
            fetchUser(userId: userId)
        }
    }

    private func fetchUser(userId: String) {
        UserAPI.shared.showUser(userId: userId) { [weak self](result) in
            self?.handlerUpdateUser(result)
        }
    }

    private func handlerUpdateUser(_ result: APIResult<UserResponse>, notifyContact: Bool = false) {
        switch result {
        case let .success(user):
            UserDAO.shared.updateUsers(users: [user], notifyContact: notifyContact)
            self.user = UserItem.createUser(from: user)
            renderUser()
            tableView.reloadData()
        case let .failure(_, didHandled):
            guard !didHandled else {
                return
            }
            NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.TOAST_OPERATION_FAILED)
        }
    }

    private func renderUser() {
        guard let user = self.user else {
            avatarImageView.setImage(with: userAvatar, identityNumber: identityNumber, name: fullName)
            fullnameLabel.text = fullName
            idLabel.text = Localized.PROFILE_MIXIN_ID(id: identityNumber)
            verifiedImageView.isHidden = true
            return
        }

        avatarImageView.setImage(with: user)
        fullnameLabel.text = user.fullName
        idLabel.text = Localized.PROFILE_MIXIN_ID(id: user.identityNumber)
        render(isMuted: user.isMuted)
        if user.isVerified {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_verified")
            verifiedImageView.isHidden = false
        } else if user.isBot {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_bot")
            verifiedImageView.isHidden = false
        } else {
            verifiedImageView.isHidden = true
        }
        switch user.relationship {
        case Relationship.FRIEND.rawValue:
            aliasNameEditButton.isHidden = false
            removeOrBlockLabel.text = Localized.PROFILE_REMOVE
        case Relationship.STRANGER.rawValue:
            aliasNameEditButton.isHidden = true
            addOrUnblockLabel.textColor = UIColor.systemTint
            addOrUnblockLabel.text = Localized.PROFILE_ADD
            removeOrBlockLabel.text = Localized.PROFILE_BLOCK
        case Relationship.ME.rawValue:
            aliasNameEditButton.isHidden = true
        case Relationship.BLOCKING.rawValue:
            addOrUnblockLabel.textColor = UIColor.red
            addOrUnblockLabel.text = Localized.PROFILE_UNBLOCK
        default:
            break
        }
    }
    
    private func render(isMuted: Bool) {
        if isMuted {
            muteLabel.text = Localized.PROFILE_STATUS_MUTED
            if let muteUntil = user?.muteUntil {
                let date = DateFormatter.dateSimple.string(from: muteUntil.toUTCDate())
                muteDetailLabel.text = Localized.PROFILE_MUTE_DURATION_PREFIX + date
            }
        } else {
            muteLabel.text = Localized.PROFILE_STATUS_NOT_MUTED
            muteDetailLabel.text = Localized.PROFILE_STATUS_NO
        }
    }

    class func instance(user: UserItem) -> UIViewController {
        let vc = Storyboard.contact.instantiateViewController(withIdentifier: "profile") as! InfoViewController
        vc.user = user
        vc.userId = user.userId
        return ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_TITLE)
    }

    class func instance(userId: String, userAvatar: String, userIdentityNumber: String, fullName: String, reputation: Int = 0) -> UIViewController {
        let vc = Storyboard.contact.instantiateViewController(withIdentifier: "profile") as! InfoViewController
        vc.userId = userId
        vc.userAvatar = userAvatar
        vc.identityNumber = userIdentityNumber
        vc.fullName = fullName
        vc.reputation = reputation
        return ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_TITLE)
    }

    private func muteUserAction(muteIntervalInSeconds: Int64) {
        muteRequestInProgress = true
        if muteIntervalInSeconds == 0 {
            self.user?.muteUntil = Date().toUTCString()
            self.render(isMuted: false)
        } else {
            self.user?.muteUntil = Date(timeInterval: Double(muteIntervalInSeconds), since: Date()).toUTCString()
            self.render(isMuted: true)
        }

        let userId = self.userId
        ConversationAPI.shared.mute(userId: self.userId, duration: muteIntervalInSeconds) { [weak self] (result) in
            switch result {
            case let .success(response):
                UserDAO.shared.updateNotificationEnabled(userId: userId, muteUntil: response.muteUntil)
            case let .failure(_, didHandled):
                guard !didHandled else {
                    return
                }
                NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.TOAST_OPERATION_FAILED)
            }
            self?.muteRequestInProgress = false
        }
    }
}

extension InfoViewController {

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return CGFloat.leastNormalMagnitude
        } else if user?.relationship == Relationship.FRIEND.rawValue && section == 1 {
            return CGFloat.leastNormalMagnitude
        }
        return super.tableView(tableView, heightForHeaderInSection: section)
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if user?.relationship == Relationship.FRIEND.rawValue && section == 1 {
            return CGFloat.leastNormalMagnitude
        }
        return super.tableView(tableView, heightForFooterInSection: section)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let user = self.user, user.isBot, section == 0 else {
            return nil
        }
        return user.appDescription
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let user = self.user {
            if user.relationship == Relationship.FRIEND.rawValue && section == 1 {
                return 0
            } else if user.relationship == Relationship.STRANGER.rawValue && section == 4 {
                return 1
            }
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        switch user?.relationship ?? Relationship.ME.rawValue {
        case Relationship.ME.rawValue:
            return 1
        case Relationship.BLOCKING.rawValue:
            return 2
        case Relationship.FRIEND.rawValue, Relationship.STRANGER.rawValue:
            return 5
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let user = self.user else {
            return
        }

        switch indexPath.section {
        case 1:
            if user.relationship == Relationship.BLOCKING.rawValue {
                unblockUserAction()
            } else {
                addContactAction()
            }
        case 2:
            if indexPath.row == 0 {
                sendMessageAction()
            } else {
                shareContactAction()
            }
        case 3:
            if !muteRequestInProgress {
                let controller = user.isMuted ? unmuteController : muteDurationController
                present(controller, animated: true, completion: nil)
            }
        case 4:
            if user.relationship == Relationship.FRIEND.rawValue {
                removeContactAction()
            } else {
                 blockUserAction()
            }
        default:
            break
        }
    }

    private func shareContactAction() {
        guard let user = self.user else {
            return
        }
        navigationController?.pushViewController(ShareContactViewController.instance(ownerUser: user), animated: true)
    }

    private func sendMessageAction() {
        guard let user = self.user, let viewControllers = navigationController?.viewControllers else {
            return
        }

        if viewControllers.count > 1, let conversationVC = viewControllers[viewControllers.count - 2] as? ConversationViewController, conversationVC.dataSource?.conversation.ownerId == user.userId {
            navigationController?.popViewController(animated: true)
        } else {
            navigationController?.pushViewController(ConversationViewController.instance(ownerUser: user), animated: true)
        }
    }

    private func blockUserAction() {
        guard let user = self.user else {
            return
        }

        displayActionLoading(loadingView: removeOrBlockLoadingView, label: removeOrBlockLabel, show: true)
        UserAPI.shared.blockUser(userId: user.userId) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
             weakSelf.displayActionLoading(loadingView: weakSelf.removeOrBlockLoadingView, label: weakSelf.removeOrBlockLabel, show: false)
            weakSelf.handlerUpdateUser(result)
        }
    }

    private func removeContactAction() {
        guard let user = self.user else {
            return
        }

        displayActionLoading(loadingView: removeOrBlockLoadingView, label: removeOrBlockLabel, show: true)
        UserAPI.shared.removeFriend(userId: user.userId, completion: { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.displayActionLoading(loadingView: weakSelf.removeOrBlockLoadingView, label: weakSelf.removeOrBlockLabel, show: false)
            weakSelf.handlerUpdateUser(result, notifyContact: true)
        })
    }

    private func addContactAction() {
        guard let user = self.user else {
            return
        }

        displayActionLoading(loadingView: addOrUnblockLoadingView, label: addOrUnblockLabel, show: true)
        UserAPI.shared.addFriend(userId: user.userId, full_name: user.fullName, completion: { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.displayActionLoading(loadingView: weakSelf.addOrUnblockLoadingView, label: weakSelf.addOrUnblockLabel, show: false)
            weakSelf.handlerUpdateUser(result, notifyContact: true)
        })
    }

    private func unblockUserAction() {
        guard let user = self.user else {
            return
        }

        displayActionLoading(loadingView: addOrUnblockLoadingView, label: addOrUnblockLabel, show: true)
        UserAPI.shared.unblockUser(userId: user.userId, completion: { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.displayActionLoading(loadingView: weakSelf.addOrUnblockLoadingView, label: weakSelf.addOrUnblockLabel, show: false)
            weakSelf.handlerUpdateUser(result)
        })
    }

    private func displayActionLoading(loadingView: UIActivityIndicatorView, label: UILabel, show: Bool) {
        loadingView.isHidden = !show
        if show {
            loadingView.startAnimating()
        } else {
            loadingView.stopAnimating()
        }
        label.isHidden = show
    }
}

