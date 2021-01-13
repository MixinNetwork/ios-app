import UIKit
import MixinServices

class CircleEditorViewController: PeerViewController<[CircleMember], CheckmarkPeerCell, CircleMemberSearchResult> {
    
    override class var showSelectionsOnTop: Bool {
        true
    }
    
    private var name = ""
    private var circleId = ""

    private var oldMembers = Set<CircleMember>()
    private var selections: [CircleMember] = [] {
        didSet {
            let count = "\(selections.count)"
            let subtitle = R.string.localizable.circle_conversation_count(count)
            container?.setSubtitle(subtitle: subtitle)
        }
    }
    
    class func instance(name: String, circleId: String, isNewCreatedCircle: Bool) -> UIViewController {
        let vc = CircleEditorViewController()
        vc.name = name
        vc.circleId = circleId
        return ContainerViewController.instance(viewController: vc, title: name)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.allowsMultipleSelection = true
        collectionView.dataSource = self
        let circleId = self.circleId
        DispatchQueue.global().async { [weak self] in
            let members = CircleDAO.shared.circleMembers(circleId: circleId)
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.selections = members
                self.oldMembers = Set<CircleMember>(members)
                self.collectionView.reloadData()
                self.reloadTableViewSelections()
                self.setCollectionViewHidden(members.isEmpty, animated: false)
            }
        }
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if let container = parent as? ContainerViewController {
            container.leftButton.tintColor = R.color.icon_tint()
            container.leftButton.setImage(R.image.ic_title_close(), for: .normal)
            container.rightButton.isEnabled = true
        }
    }
    
    override func catalog(users: [UserItem]) -> (titles: [String], models: [[CircleMember]]) {
        let conversations = ConversationDAO.shared.conversationList()
            .compactMap(CircleMember.init)
        let presentedUserIds = conversations
            .filter({ $0.category == ConversationCategory.CONTACT.rawValue })
            .map({ $0.userId })
        let presentedUserIdSet = Set(presentedUserIds)
        var contacts = [UserItem]()
        var apps = [UserItem]()
        for user in users.filter({ !presentedUserIdSet.contains($0.userId) }) {
            if user.isBot {
                apps.append(user)
            } else {
                contacts.append(user)
            }
        }
        let titles = [
            R.string.localizable.circle_member_category_chats(),
            R.string.localizable.circle_member_category_contacts(),
            R.string.localizable.circle_member_category_apps()
        ]
        let models = [
            conversations,
            contacts.map(CircleMember.init),
            apps.map(CircleMember.init),
        ]
        return (titles, models)
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 != initDataOperation })
            .forEach({ $0.cancel() })
        let op = BlockOperation()
        let members = self.models
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            let uniqueMembers = Set(members.flatMap({ $0 }))
            let searchResults = uniqueMembers
                .filter { $0.matches(lowercasedKeyword: keyword) }
                .map { CircleMemberSearchResult(member: $0, keyword: keyword) }
            DispatchQueue.main.sync {
                guard let weakSelf = self, !op.isCancelled else {
                    return
                }
                weakSelf.searchingKeyword = keyword
                weakSelf.searchResults = searchResults
                weakSelf.tableView.reloadData()
                weakSelf.reloadTableViewSelections()
            }
        }
        queue.addOperation(op)
    }
    
    override func configure(cell: CheckmarkPeerCell, at indexPath: IndexPath) {
        if isSearching {
            cell.render(result: searchResults[indexPath.row])
        } else {
            cell.render(member: models[indexPath.section][indexPath.row])
        }
    }
    
    override func reloadTableViewSelections() {
        super.reloadTableViewSelections()
        if isSearching {
            for (index, result) in searchResults.enumerated() {
                guard selections.contains(result.member) else {
                    continue
                }
                let indexPath = IndexPath(row: index, section: 0)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        } else {
            for section in 0..<models.count {
                for indexPath in indexPathsWhichMatchSelections(of: section) {
                    tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                }
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? 1 : models.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : models[section].count
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let member = circleMember(at: indexPath)
        let indexPath = IndexPath(item: selections.count, section: 0)
        selections.append(member)
        collectionView.insertItems(at: [indexPath])
        self.setCollectionViewHidden(false, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let member = circleMember(at: indexPath)
        if let index = selections.firstIndex(of: member) {
            let indexPath = IndexPath(item: index, section: 0)
            selections.remove(at: index)
            collectionView.deleteItems(at: [indexPath])
            self.setCollectionViewHidden(selections.isEmpty, animated: true)
        }
    }
    
}

extension CircleEditorViewController: ContainerViewControllerDelegate {
    
    func barLeftButtonTappedAction() {
        dismiss(animated: true, completion: nil)
    }
    
    func barRightButtonTappedAction() {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)

        let newMembers = Set<CircleMember>(selections)
        let intersectMembers = oldMembers.intersection(newMembers)
        let addMembers = newMembers.subtracting(intersectMembers).map { CircleConversationRequest.create(action: .ADD, member: $0) }
        let removeMembers = oldMembers.subtracting(intersectMembers).map { CircleConversationRequest.create(action: .REMOVE, member: $0) }

        let requests = addMembers + removeMembers
        let circleId = self.circleId
        CircleAPI.updateCircle(of: circleId, requests: requests) { (result) in
            switch result {
            case let .success(circles):
                DispatchQueue.global().async {
                    CircleConversationDAO.shared.save(circleId: circleId, objects: circles, sendNotificationAfterFinished: false)
                    CircleConversationDAO.shared.delete(circleId: circleId, conversationIds: removeMembers.map { $0.conversationId })
                    DispatchQueue.main.sync {
                        hud.set(style: .notification, text: R.string.localizable.toast_saved())
                        hud.scheduleAutoHidden()
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        }
    }
    
    func textBarRightButton() -> String? {
        R.string.localizable.action_save()
    }
    
}

extension CircleEditorViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        selections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.selected_peer, for: indexPath)!
        let member = selections[indexPath.row]
        cell.render(member: member)
        cell.delegate = self
        return cell
    }
    
}

extension CircleEditorViewController: SelectedPeerCellDelegate {
    
    func selectedPeerCellDidSelectRemove(_ cell: UICollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        let deselected = selections[indexPath.row]
        if isSearching {
            if let item = searchResults.map({ $0.member }).firstIndex(of: deselected) {
                let indexPath = IndexPath(item: item, section: 0)
                tableView.deselectRow(at: indexPath, animated: true)
                tableView(tableView, didDeselectRowAt: indexPath)
            }
        } else {
            for section in 0..<models.count {
                let members = models[section]
                if let item = members.firstIndex(of: deselected) {
                    let indexPath = IndexPath(item: item, section: section)
                    tableView.deselectRow(at: indexPath, animated: true)
                    tableView(tableView, didDeselectRowAt: indexPath)
                    break
                }
            }
        }
    }
    
}

extension CircleEditorViewController {
    
    private func indexPathsWhichMatchSelections(of section: Int) -> [IndexPath] {
        assert(!isSearching)
        var indexPaths = [IndexPath]()
        for (row, member) in models[section].enumerated() where selections.contains(member) {
            indexPaths.append(IndexPath(row: row, section: section))
        }
        return indexPaths
    }
    
    private func circleMember(at indexPath: IndexPath) -> CircleMember {
        if isSearching {
            return searchResults[indexPath.row].member
        } else {
            return models[indexPath.section][indexPath.row]
        }
    }
    
}
