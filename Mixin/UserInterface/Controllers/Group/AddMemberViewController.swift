import UIKit
import MixinServices

class AddMemberViewController: PeerViewController<[UserItem], CheckmarkPeerCell, UserSearchResult> {
    
    private var conversationId: String? = nil
    private var alreadyInGroupUserIds = Set<String>()
    private var selectedUserIds = Set<String>()
    private var selectedUsers = [UserItem]() {
        didSet {
            selectionsDidChange()
        }
    }
    
    private var isAppendingMembersToAnExistedGroup: Bool {
        return conversationId != nil
    }
    
    class func instance(appendingMembersToConversationId conversationId: String? = nil) -> UIViewController {
        let vc = AddMemberViewController()
        vc.conversationId = conversationId
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = NavigationTitleView(title: R.string.localizable.add_participants())
        let rightButtonTitle = if isAppendingMembersToAnExistedGroup {
            R.string.localizable.done()
        } else {
            R.string.localizable.next()
        }
        navigationItem.rightBarButtonItem = .busyButton(title: rightButtonTitle, target: self, action: #selector(addMember(_:)))
        navigationItem.rightBarButtonItem?.isEnabled = false
        searchBoxView.textField.placeholder = R.string.localizable.setting_auth_search_hint()
        tableView.allowsMultipleSelection = true
    }
    
    override func initData() {
        
        class ObjcAccessibleUser: NSObject {
            @objc let fullName: String
            let user: UserItem
            
            init(user: UserItem) {
                self.fullName = user.fullName
                self.user = user
                super.init()
            }
        }
        
        let conversationId = self.conversationId
        initDataOperation.addExecutionBlock { [weak self] in
            let objcAccessibleUsers = UserDAO.shared.contacts()
                .map(ObjcAccessibleUser.init)
            let (titles, objcUsers) = UILocalizedIndexedCollation.current()
                .catalog(objcAccessibleUsers, usingSelector: #selector(getter: ObjcAccessibleUser.fullName))
            let users = objcUsers.map({ $0.map({ $0.user }) })
            let participantUserIds: Set<String>
            if let conversationId = conversationId {
                let participants = ParticipantDAO.shared.participants(conversationId: conversationId)
                participantUserIds = Set(participants.map({ $0.userId }))
            } else {
                participantUserIds = Set()
            }
            guard let weakSelf = self else {
                return
            }
            DispatchQueue.main.sync {
                weakSelf.sectionTitles = titles
                weakSelf.models = users
                weakSelf.alreadyInGroupUserIds = participantUserIds
                weakSelf.updateSubtitle()
                weakSelf.tableView.reloadData()
            }
        }
        queue.addOperation(initDataOperation)
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 != initDataOperation })
            .forEach({ $0.cancel() })
        let op = BlockOperation()
        let users = self.models
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            let searchResult = users.flatMap({ $0 })
                .filter({ $0.matches(lowercasedKeyword: keyword) })
                .map({ UserSearchResult(user: $0, keyword: keyword) })
            DispatchQueue.main.sync {
                guard let weakSelf = self, !op.isCancelled else {
                    return
                }
                weakSelf.searchingKeyword = keyword
                weakSelf.searchResults = [searchResult]
                weakSelf.tableView.reloadData()
                weakSelf.reloadTableViewSelections()
            }
        }
        queue.addOperation(op)
    }
    
    override func reloadTableViewSelections() {
        super.reloadTableViewSelections()
        if isSearching {
            enumerateSearchResults { result, indexPath, _ in
                if selectedUserIds.contains(result.user.userId) {
                    tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                }
            }
        } else {
            for (section, users) in models.enumerated() {
                for (row, user) in users.enumerated() where selectedUserIds.contains(user.userId){
                    let indexPath = IndexPath(row: row, section: section)
                    tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                }
            }
        }
    }
    
    override func configure(cell: CheckmarkPeerCell, at indexPath: IndexPath) {
        let user: UserItem
        if isSearching {
            let searchResult = searchResults[indexPath.section][indexPath.row]
            cell.render(result: searchResult)
            user = searchResult.user
        } else {
            user = models[indexPath.section][indexPath.row]
            cell.render(user: user)
        }
        if alreadyInGroupUserIds.contains(user.userId) {
            cell.isForceSelected = true
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults[section].count : models[section].count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? 1 : sectionTitles.count
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let user = self.user(at: indexPath)
        if alreadyInGroupUserIds.contains(user.userId) {
            return nil
        } else if selectedUserIds.count + alreadyInGroupUserIds.count == maxGroupMemberCount {
            showAutoHiddenHud(style: .error, text: R.string.localizable.group_participant_add_full())
            return nil
        } else if selectedUserIds.count == 50 {
            showAutoHiddenHud(style: .error, text: R.string.localizable.group_participant_add_limit())
            return nil
        } else {
            return indexPath
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = self.user(at: indexPath)
        let inserted = selectedUserIds.insert(user.userId).inserted
        if inserted {
            selectedUsers.append(user)
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let user = self.user(at: indexPath)
        guard let idx = selectedUsers.firstIndex(where: { $0.userId == user.userId }) else {
            return
        }
        selectedUsers.remove(at: idx)
        selectedUserIds.remove(user.userId)
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        isSearching ? nil : sectionTitles
    }
    
    private func selectionsDidChange() {
        updateSubtitle()
        navigationItem.rightBarButtonItem?.isEnabled = !selectedUsers.isEmpty
    }
    
    private func updateSubtitle() {
        guard let titleView = navigationItem.titleView as? NavigationTitleView else {
            return
        }
        titleView.subtitle = "\(selectedUsers.count + alreadyInGroupUserIds.count)/\(maxGroupMemberCount)"
    }
    
    private func user(at indexPath: IndexPath) -> UserItem {
        if isSearching {
            return searchResults[indexPath.section][indexPath.row].user
        } else {
            return models[indexPath.section][indexPath.row]
        }
    }
    
    @objc private func addMember(_ sender: BusyButton) {
        if let conversationId = conversationId {
            let userIds = selectedUsers.map { $0.userId }
            sender.isBusy = true
            ConversationAPI.addParticipant(conversationId: conversationId, participantUserIds: userIds, completion: { [weak self] (result) in
                guard let weakSelf = self else {
                    return
                }
                sender.isBusy = false
                switch result {
                case .success:
                    weakSelf.navigationController?.popViewController(animated: true)
                case let .failure(error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            })
        } else {
            let members = selectedUsers.map(GroupMemberCandidate.init)
            let newGroup = NewGroupViewController(members: members)
            navigationController?.pushViewController(newGroup, animated: true)
        }
    }
    
}
