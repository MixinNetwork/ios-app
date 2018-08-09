import UIKit

class NewGroupViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private let groupNameCellReuseId = "GroupName"
    private let groupMemberCellReuseId = "GroupMember"
    private let conversationId = UUID().uuidString.lowercased()

    private var rightButton: StateResponsiveButton?
    private var groupNameCell: GroupNameCell!
    private var staticCells: [UITableViewCell]!
    private var members = [GroupUser]()

    private var groupName: String {
        return groupNameCell.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "GroupMemberCell", bundle: .main), forCellReuseIdentifier: groupMemberCellReuseId)
        groupNameCell = tableView.dequeueReusableCell(withIdentifier: groupNameCellReuseId) as! GroupNameCell
        staticCells = [groupNameCell]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()

        groupNameCell.textField.addTarget(self, action: #selector(nameChangedAction(_:)), for: .editingChanged)
        groupNameCell.textField.becomeFirstResponder()
    }

    @objc func nameChangedAction(_ sender: Any) {
        rightButton?.isEnabled = !groupName.isEmpty
    }

    @IBAction func popAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    private func createAction() {
        guard let rightButton = self.rightButton else {
            return
        }

        rightButton.isBusy = true

        let converstionId = self.conversationId
        let name = self.groupName
        let members = self.members

        DispatchQueue.global().async { [weak self] in
            if ConversationDAO.shared.createConversation(conversationId: converstionId, name: name, members: members) || ConversationDAO.shared.isExist(conversationId: converstionId) {
                DispatchQueue.main.async {
                    self?.createConversation(name: name)
                }
            } else {
                DispatchQueue.main.async {
                    self?.rightButton?.isBusy = false
                }
            }
        }
    }

    private func createConversation(name: String) {
        let participants = members.flatMap { (user) -> ParticipantRequest in
            return ParticipantRequest(userId: user.userId, role: "")
        }
        let request = ConversationRequest(conversationId: conversationId, name: name, category: ConversationCategory.GROUP.rawValue, participants: participants, duration: nil, announcement: nil)
        ConversationAPI.shared.createConversation(conversation: request) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(response):
                weakSelf.saveConversation(conversation: response)
            case .failure:
                weakSelf.rightButton?.isBusy = false
            }
        }
    }

    private func saveConversation(conversation: ConversationResponse) {
        DispatchQueue.global().async { [weak self] in
            guard ConversationDAO.shared.createConversation(conversation: conversation, targetStatus: .SUCCESS) else {
                DispatchQueue.main.async {
                    self?.rightButton?.isBusy = false
                }
                return
            }
            guard let conversation = ConversationDAO.shared.getConversation(conversationId: conversation.conversationId) else {
                return
            }
            DispatchQueue.main.async {
                self?.navigationController?.pushViewController(withBackRoot: ConversationViewController.instance(conversation: conversation))
            }
        }
    }

    class func instance(members: [GroupUser]) -> UIViewController {
        let vc = Storyboard.group.instantiateViewController(withIdentifier: "new_group") as! NewGroupViewController
        vc.members = members
        return ContainerViewController.instance(viewController: vc, title: Localized.GROUP_NAVIGATION_TITLE_NEW_GROUP)
    }

}

extension NewGroupViewController: ContainerViewControllerDelegate {

    func barRightButtonTappedAction() {
        createAction()
    }

    func textBarRightButton() -> String? {
        return Localized.GROUP_BUTTON_TITLE_CREATE
    }

    func prepareBar(rightButton: StateResponsiveButton) {
        self.rightButton = rightButton
    }

}

extension NewGroupViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return staticCells.count
        } else {
            return members.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            return staticCells[indexPath.row]
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: groupMemberCellReuseId) as! GroupMemberCell
            cell.render(user: members[indexPath.row])
            return cell
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

}

extension NewGroupViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return indexPath.row == 0 ? 60 : 44
        default:
            return 60
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? .leastNormalMagnitude : 20
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 10
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else {
            return
        }

        if indexPath.row == 0 {
            changeNameAction()
        }
    }

    private func changeNameAction() {
        groupNameCell.textField.becomeFirstResponder()
    }
    
}
