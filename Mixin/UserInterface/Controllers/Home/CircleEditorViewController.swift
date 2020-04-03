import UIKit
import MixinServices

class CircleEditorViewController: PeerViewController<[CircleMember], CheckmarkPeerCell, CircleMemberSearchResult> {
    
    enum Intent {
        case create
        case update(id: String)
    }
    
    let collectionViewLayout = UICollectionViewFlowLayout()
    
    var collectionView: UICollectionView!
    
    private var name = ""
    private var intent: Intent!
    private var selections: [CircleMember] = [] {
        didSet {
            let count = "\(selections.count)"
            let subtitle = R.string.localizable.circle_conversation_count(count)
            container?.setSubtitle(subtitle: subtitle)
        }
    }
    
    class func instance(name: String, intent: Intent) -> UIViewController {
        let vc = CircleEditorViewController()
        vc.name = name
        vc.intent = intent
        let title: String
        switch intent {
        case .create:
            title = R.string.localizable.circle_action_add_conversation()
        case .update:
            title = name
        }
        return ContainerViewController.instance(viewController: vc, title: title)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_name()
        tableView.allowsMultipleSelection = true
        centerWrapperViewHeightConstraint.constant = 90
        collectionViewLayout.itemSize = CGSize(width: 66, height: 80)
        collectionViewLayout.minimumInteritemSpacing = 0
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.backgroundColor = .background
        collectionView.alwaysBounceHorizontal = true
        centerWrapperView.addSubview(collectionView)
        collectionView.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-10)
        }
        collectionView.register(R.nib.circleMemberCell)
        collectionView.dataSource = self
        switch intent! {
        case .create:
            break
        case .update(let id):
            DispatchQueue.global().async { [weak self] in
                let members = CircleDAO.shared.circleMembers(circleId: id)
                DispatchQueue.main.sync {
                    guard let self = self else {
                        return
                    }
                    self.selections = members
                    self.collectionView.reloadData()
                    self.reloadTableViewSelections()
                }
            }
        }
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if let container = parent as? ContainerViewController {
            container.leftButton.tintColor = .text
            container.leftButton.setImage(R.image.ic_title_close(), for: .normal)
            container.rightButton.isEnabled = true
        }
    }
    
    override func catalog(users: [UserItem]) -> (titles: [String], models: [[CircleMember]]) {
        let conversations = ConversationDAO.shared.conversationList()
            .compactMap(CircleMember.init)
        let presentedUserIds = conversations
            .filter({ $0.category == ConversationCategory.CONTACT.rawValue })
            .map({ $0.ownerId })
        let presentedUserIdSet = Set(presentedUserIds)
        var contacts = [UserItem]()
        var bots = [UserItem]()
        for user in users.filter({ !presentedUserIdSet.contains($0.userId) }) {
            if user.isBot {
                bots.append(user)
            } else {
                contacts.append(user)
            }
        }
        let titles = [
            R.string.localizable.circle_member_category_chats(),
            R.string.localizable.circle_member_category_contacts(),
            R.string.localizable.circle_member_category_bots()
        ]
        let models = [
            conversations,
            contacts.map(CircleMember.init),
            bots.map(CircleMember.init)
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
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let member = circleMember(at: indexPath)
        if let index = selections.firstIndex(of: member) {
            let indexPath = IndexPath(item: index, section: 0)
            selections.remove(at: index)
            collectionView.deleteItems(at: [indexPath])
        }
    }
    
}

extension CircleEditorViewController: ContainerViewControllerDelegate {
    
    func barLeftButtonTappedAction() {
        dismiss(animated: true, completion: nil)
    }
    
    func barRightButtonTappedAction() {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.window)
        switch intent! {
        case .create:
            let selections = self.selections
            CircleAPI.shared.create(name: name) { (result) in
                switch result {
                case .success(let circle):
                    if selections.isEmpty {
                        DispatchQueue.global().async {
                            CircleDAO.shared.insertOrReplace(circle: circle)
                            DispatchQueue.main.sync {
                                hud.set(style: .notification, text: R.string.localizable.toast_saved())
                                hud.scheduleAutoHidden()
                                self.dismiss(animated: true, completion: nil)
                            }
                        }
                    } else {
                        self.intent = .update(id: circle.circleId)
                        DispatchQueue.global().async {
                            CircleDAO.shared.insertOrReplace(circle: circle)
                            self.updateCircle(of: circle.circleId, with: selections, hud: hud)
                        }
                    }
                case .failure(let error):
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        case let .update(id):
            self.updateCircle(of: id, with: selections, hud: hud)
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.circle_member, for: indexPath)!
        let member = selections[indexPath.row]
        cell.render(member: member)
        cell.delegate = self
        return cell
    }
    
}

extension CircleEditorViewController: CircleMemberCellDelegate {
    
    func circleMemberCellDidSelectRemove(_ cell: UICollectionViewCell) {
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
    
    private func updateCircle(of id: String, with members: [CircleMember], hud: Hud) {
        let requests = members.map(UpdateCircleMemberRequest.init)
        CircleAPI.shared.updateCircle(of: id, requests: requests) { (result) in
            switch result {
            case .success:
                DispatchQueue.global().async {
                    let date = Date()
                    let counter = Counter(value: -1)
                    let objects = members.map { (member) -> CircleConversation in
                        let createdAt = date
                            .addingTimeInterval(TimeInterval(counter.advancedValue) / millisecondsPerSecond)
                            .toUTCString()
                        return CircleConversation(circleId: id,
                                                  conversationId: member.conversationId,
                                                  createdAt: createdAt)
                    }
                    CircleConversationDAO.shared.replaceCircleConversations(with: id, objects: objects)
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
    
}
