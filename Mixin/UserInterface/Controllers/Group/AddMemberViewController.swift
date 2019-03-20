import UIKit

class AddMemberViewController: UIViewController {

    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var participantsLabel: UILabel!
    @IBOutlet weak var nextButton: StateResponsiveButton!
    
    private typealias Section = [GroupUser]
    
    private enum ReuseId {
        static let header = "header"
        static let cell = "cell"
    }
    private let maxMembersCount = 256
    
    private var sections = [Section]()
    private var indexPaths = [GroupUser: IndexPath]()
    private var titles = [String]()
    private var searchResult = [GroupUser]()
    private var selections = [GroupUser]() {
        didSet {
            nextButton.isEnabled = !selections.isEmpty
            participantsLabel.text = "\(selections.count + alreadyInGroupUserIds.count)/\(maxMembersCount)"
        }
    }
    private var alreadyInGroupUserIds = Set<String>()
    private var conversationId: String?
    private var isAppendingMembersToAnExistedGroup: Bool {
        return conversationId != nil
    }
    private var isSearching: Bool {
        return !(searchBoxView.textField.text ?? "").isEmpty
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.addTarget(self, action: #selector(search(_:)), for: .editingChanged)
        tableView.register(UINib(nibName: "PeerCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.cell)
        tableView.register(GeneralTableViewHeader.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        nextButton.isEnabled = false
        if isAppendingMembersToAnExistedGroup {
            nextButton.setTitle(Localized.ACTION_DONE, for: .normal)
        }
        searchBoxView.textField.delegate = self
        reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
    
    class func instance(appendMembersToExistedGroupOfConversationId conversationId: String? = nil) -> UIViewController {
        let vc = Storyboard.group.instantiateInitialViewController() as! AddMemberViewController
        vc.conversationId = conversationId
        return vc
    }
    
    @IBAction func popAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func nextAction(_ sender: Any) {
        guard !selections.isEmpty else {
            return
        }
        if let conversationId = conversationId {
            nextButton.isBusy = true
            let userIds = selections.map({ $0.userId })
            ConversationAPI.shared.addParticipant(conversationId: conversationId, participantUserIds: userIds, completion: { [weak self](result) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.nextButton.isBusy = false
                switch result {
                case .success:
                    weakSelf.navigationController?.popViewController(animated: true)
                case let .failure(error):
                    showHud(style: .error, text: error.localizedDescription)
                }
            })
        } else {
            let vc = NewGroupViewController.instance(members: selections)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @objc func search(_ sender: Any) {
        let keyword = (searchBoxView.textField.text ?? "").uppercased()
        if keyword.isEmpty {
            searchResult = []
        } else {
            searchResult = sections
                .flatMap({ $0 })
                .filter({ $0.fullName.uppercased().contains(keyword) })
        }
        reloadTableViewAndSetSelections()
    }
    
}

extension AddMemberViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResult.count : sections[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.cell) as! PeerCell
        let user = self.user(at: indexPath)
        let userIsAlreayInGroup = alreadyInGroupUserIds.contains(user.userId)
        cell.render(user: user, forceSelected: userIsAlreayInGroup)
        cell.supportsMultipleSelection = true
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? 1 : sections.count
    }

}

extension AddMemberViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isSearching {
            return nil
        } else {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! GeneralTableViewHeader
            header.label.text = titles[section]
            return header
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return isSearching ? .leastNormalMagnitude : 30
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard selections.count + alreadyInGroupUserIds.count < maxMembersCount else {
            return nil
        }
        let user = self.user(at: indexPath)
        return alreadyInGroupUserIds.contains(user.userId) ? nil : indexPath
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = self.user(at: indexPath)
        selections.append(user)
    }
    
    func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        let user = self.user(at: indexPath)
        return alreadyInGroupUserIds.contains(user.userId) ? nil : indexPath
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let index = selections.index(of: user(at: indexPath)) else {
            return
        }
        selections.remove(at: index)
    }
    
}

extension AddMemberViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchBoxView.textField.text = nil
        searchBoxView.textField.resignFirstResponder()
        reloadTableViewAndSetSelections()
        return false
    }

}

extension AddMemberViewController {
    
    private func user(at indexPath: IndexPath) -> GroupUser {
        if isSearching {
            return searchResult[indexPath.row]
        } else {
            return sections[indexPath.section][indexPath.row]
        }
    }
    
    private func reloadData() {
        DispatchQueue.global().async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            let contacts = UserDAO.shared.contacts()
                .map({ GroupUser(userId: $0.userId, identityNumber: $0.identityNumber, fullName: $0.fullName, avatarUrl: $0.avatarUrl, isVerified: $0.isVerified, isBot: $0.isBot) })
            if let conversationId = weakSelf.conversationId {
                let participants = ParticipantDAO.shared.participants(conversationId: conversationId)
                weakSelf.alreadyInGroupUserIds = Set(participants.map({ $0.userId }))
                DispatchQueue.main.async {
                    weakSelf.participantsLabel.text = "\(participants.count)/\(weakSelf.maxMembersCount)"
                }
            }
            (weakSelf.titles, weakSelf.sections) = UILocalizedIndexedCollation.current().catalogue(contacts, usingSelector: #selector(getter: GroupUser.fullName))
            for (sectionIndex, section) in weakSelf.sections.enumerated() {
                for (rowIndex, user) in section.enumerated() {
                    weakSelf.indexPaths[user] = IndexPath(row: rowIndex, section: sectionIndex)
                }
            }
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
    }
    
    private func reloadTableViewAndSetSelections() {
        tableView.reloadData()
        if isSearching {
            for selection in selections {
                if let row = searchResult.index(of: selection) {
                    let indexPath = IndexPath(row: row, section: 0)
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                }
            }
        } else {
            for selection in selections {
                if let indexPath = indexPaths[selection] {
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                }
            }
        }
    }
    
}
