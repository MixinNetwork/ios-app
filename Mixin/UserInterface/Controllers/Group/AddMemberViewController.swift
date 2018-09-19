import UIKit

class AddMemberViewController: UIViewController {

    @IBOutlet weak var keywordTextField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var participantsLabel: UILabel!
    @IBOutlet weak var nextButton: StateResponsiveButton!
    
    private typealias Section = [GroupUser]

    private let headerReuseId = "Header"
    private let memberSelectionCellReuseId = "MemberSelection"
    
    private var sections = [Section]()
    private var indexPaths = [GroupUser: IndexPath]()
    private var titles = [String]()
    private var searchResult = [GroupUser]()
    private var selections = [GroupUser]() {
        didSet {
            nextButton.isEnabled = !selections.isEmpty
            participantsLabel.text = "\(selections.count + oldParticipantCount)/256"
        }
    }
    private var oldParticipantCount = 0
    private var isSearching: Bool {
        return !(keywordTextField.text ?? "").isEmpty
    }
    private var conversationId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(GeneralTableViewHeader.self, forHeaderFooterViewReuseIdentifier: headerReuseId)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        nextButton.isEnabled = false
        if conversationId != nil {
            nextButton.setTitle(Localized.ACTION_DONE, for: .normal)
        }
        keywordTextField.delegate = self
        fetchContacts()
    }

    class func instance(conversationId: String? = nil) -> UIViewController {
        let vc = Storyboard.group.instantiateInitialViewController() as! AddMemberViewController
        vc.conversationId = conversationId
        return vc
    }
    
    @IBAction func popAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func nextAction(_ sender: Any) {
        nextAction()
    }
    
    private func nextAction() {
        guard selections.count > 0 else {
            return
        }

        if let conversationId = self.conversationId {
            nextButton.isBusy = true
            ConversationAPI.shared.addParticipant(conversationId: conversationId, participants: selections, completion: { [weak self](result) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.nextButton.isBusy = false
                switch result {
                case .success:
                    weakSelf.navigationController?.popViewController(animated: true)
                case .failure:
                    break
                }
            })
        } else {
            let vc = NewGroupViewController.instance(members: selections)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @IBAction func searchAction(_ sender: Any) {
        let keyword = (keywordTextField.text ?? "").uppercased()
        if keyword.isEmpty {
            searchResult = []
        } else {
            searchResult = sections.flatMap({ $0 }).filter({ $0.fullName.uppercased().contains(keyword) })
        }
        reloadTableViewAndSetSelections()
    }
    
    private func fetchContacts() {
        DispatchQueue.global().async { [weak self] in
            var contacts = UserDAO.shared.contacts()
                .map({ GroupUser(userId: $0.userId, identityNumber: $0.identityNumber, fullName: $0.fullName, avatarUrl: $0.avatarUrl, isVerified: $0.isVerified, isBot: $0.isBot) })
            if let weakSelf = self {
                if let conversationId = weakSelf.conversationId {
                    let participants = ParticipantDAO.shared.participants(conversationId: conversationId)
                    weakSelf.oldParticipantCount = participants.count
                    for participant in participants {
                        guard let idx = contacts.index(where: { (user) -> Bool in
                            return user.userId == participant.userId
                        }) else {
                            continue
                        }
                        contacts[idx].disabled = true
                    }
                    DispatchQueue.main.async {
                        weakSelf.participantsLabel.text = "\(weakSelf.oldParticipantCount)/256"
                    }
                }
                (weakSelf.titles, weakSelf.sections) = UILocalizedIndexedCollation.current().catalogue(contacts, usingSelector: #selector(getter: GroupUser.fullName))
                for (sectionIndex, section) in weakSelf.sections.enumerated() {
                    for (rowIndex, user) in section.enumerated() {
                        weakSelf.indexPaths[user] = IndexPath(row: rowIndex, section: sectionIndex)
                    }
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

extension AddMemberViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResult.count : sections[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: memberSelectionCellReuseId) as! GroupMemberSelectionCell
        let user: GroupUser
        if isSearching {
            user = searchResult[indexPath.row]
        } else {
            user = sections[indexPath.section][indexPath.row]
        }
        cell.render(user: user)
        if !user.disabled && selections.contains(user) {
            cell.setSelected(true, animated: false)
        }
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
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! GeneralTableViewHeader
            header.label.text = titles[section]
            return header
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return isSearching ? .leastNormalMagnitude : 30
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard selections.count < 256 else {
            return
        }
        if isSearching {
            guard !searchResult[indexPath.row].disabled else {
                return
            }
            selections.append(searchResult[indexPath.row])
        } else {
            guard !sections[indexPath.section][indexPath.row].disabled else {
                return
            }
            selections.append(sections[indexPath.section][indexPath.row])
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isSearching {
            guard !searchResult[indexPath.row].disabled else {
                return
            }
            if let index = selections.index(of: searchResult[indexPath.row]) {
                selections.remove(at: index)
            }
        } else {
            guard !sections[indexPath.section][indexPath.row].disabled else {
                return
            }
            if let index = selections.index(of: sections[indexPath.section][indexPath.row]) {
                selections.remove(at: index)
            }
        }
    }

}

extension AddMemberViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        keywordTextField.text = nil
        keywordTextField.resignFirstResponder()
        reloadTableViewAndSetSelections()
        return false
    }

}
