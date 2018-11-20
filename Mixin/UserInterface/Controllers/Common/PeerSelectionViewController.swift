import UIKit

class PeerSelectionViewController: UIViewController, ContainerViewControllerDelegate {
    
    enum Content {
        case chatsAndContacts
        case contacts
        case transferReceivers
        case catalogedContacts
    }
    
    private let searchBoxView = SearchBoxView()
    private let tableView = UITableView()
    
    private var headerTitles = [String]()
    private var peers = [[Peer]]()
    private var searchResults = [Peer]()
    private var selections = Set<Peer>() {
        didSet {
            container?.rightButton.isEnabled = selections.count > 0
        }
    }
    private var sortedSelections = [Peer]()
    
    private var isSearching: Bool {
        if let text = searchBoxView.textField.text {
            return !text.isEmpty
        } else {
            return false
        }
    }
    
    var allowsMultipleSelection: Bool {
        return true
    }
    
    var content: Content {
        return .chatsAndContacts
    }
    
    override func loadView() {
        view = UIView()
        view.addSubview(searchBoxView)
        view.addSubview(tableView)
        searchBoxView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(44)
        }
        tableView.snp.makeConstraints { (make) in
            make.top.equalTo(searchBoxView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.addTarget(self,
                                          action: #selector(search(_:)),
                                          for: .editingChanged)
        tableView.keyboardDismissMode = .onDrag
        tableView.allowsMultipleSelection = allowsMultipleSelection
        tableView.rowHeight = 60
        tableView.register(UINib(nibName: "PeerCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.cell)
        tableView.register(GeneralTableViewHeader.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        reloadData()
    }
    
    @objc func search(_ sender: Any) {
        let keyword = (searchBoxView.textField.text ?? "").uppercased()
        if keyword.isEmpty {
            searchResults = []
        } else {
            var unique = Set<Peer>()
            searchResults = peers
                .flatMap({ $0 })
                .filter({ $0.name.uppercased().contains(keyword) })
                .filter({ unique.insert($0).inserted })
        }
        tableView.reloadData()
        reloadSelections()
    }
    
    func work(selections: [Peer]) {
        
    }
    
    func popToConversationWithLastSelection() {
        if let peer = sortedSelections.last {
            let vc: ConversationViewController
            switch peer.item {
            case .conversation(let conversation):
                vc = ConversationViewController.instance(conversation: conversation)
            case .user(let user):
                vc = ConversationViewController.instance(ownerUser: user)
            }
            navigationController?.pushViewController(withBackRoot: vc)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    // MARK: ContainerViewControllerDelegate
    func prepareBar(rightButton: StateResponsiveButton) {
        rightButton.setTitleColor(.systemTint, for: .normal)
    }
    
    func barRightButtonTappedAction() {
        work(selections: sortedSelections)
    }
    
    func textBarRightButton() -> String? {
        return nil
    }
    
}

extension PeerSelectionViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard !peers.isEmpty else {
            return 0
        }
        return isSearching ? searchResults.count : peers[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.cell) as! PeerCell
        let peer = self.peer(at: indexPath)
        cell.render(peer: peer)
        cell.supportsMultipleSelection = allowsMultipleSelection
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? 1 : peers.count
    }
    
}

extension PeerSelectionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !isSearching, !headerTitles.isEmpty else {
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! GeneralTableViewHeader
        header.label.text = headerTitles[section]
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let showHeader = !isSearching && !headerTitles.isEmpty
        return showHeader ? 30 : .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peer = self.peer(at: indexPath)
        if allowsMultipleSelection {
            let inserted = selections.insert(peer).inserted
            if inserted {
                sortedSelections.append(peer)
            }
            reloadSelections()
        } else {
            work(selections: [peer])
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let peer = self.peer(at: indexPath)
        selections.remove(peer)
        if let index = sortedSelections.firstIndex(of: peer) {
            sortedSelections.remove(at: index)
        }
        reloadSelections()
    }
    
}

extension PeerSelectionViewController {
    
    private enum ReuseId {
        static let cell = "cell"
        static let header = "header"
    }
    
    private static func catalogedPeers(from users: [UserItem]) -> (titles: [String], peers: [[Peer]]) {
        
        class ObjcAccessiblePeer: NSObject{
            @objc let fullName: String
            let peer: Peer
            
            init(user: UserItem) {
                self.fullName = user.fullName
                self.peer = Peer(user: user)
                super.init()
            }
        }
        
        let objcAccessibleUsers = users.map(ObjcAccessiblePeer.init)
        let (titles, objcUsers) = UILocalizedIndexedCollation
            .current()
            .catalogue(objcAccessibleUsers, usingSelector: #selector(getter: ObjcAccessiblePeer.fullName))
        let peers = objcUsers.map({ $0.map({ $0.peer }) })
        return (titles, peers)
    }
    
    private func peer(at indexPath: IndexPath) -> Peer {
        if isSearching {
            return searchResults[indexPath.row]
        } else {
            return peers[indexPath.section][indexPath.row]
        }
    }
    
    private func reloadData() {
        let content = self.content
        DispatchQueue.global().async {
            let titles: [String]
            let peers: [[Peer]]
            let contacts = UserDAO.shared.contacts()
            switch content {
            case .chatsAndContacts:
                let conversations = ConversationDAO.shared.conversationList()
                titles = [Localized.CHAT_FORWARD_CHATS,
                          Localized.CHAT_FORWARD_CONTACTS]
                peers = [conversations.map(Peer.init),
                         contacts.map(Peer.init)]
            case .contacts:
                titles = []
                peers = [contacts.map(Peer.init)]
            case .transferReceivers:
                titles = []
                let transferReceivers = contacts.filter({ (user) -> Bool in
                    if user.isBot {
                        return user.appCreatorId == AccountAPI.shared.accountUserId
                    } else {
                        return true
                    }
                })
                peers = [transferReceivers.map(Peer.init)]
            case .catalogedContacts:
                (titles, peers) = PeerSelectionViewController.catalogedPeers(from: contacts)
            }
            DispatchQueue.main.async { [weak self] in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.headerTitles = titles
                weakSelf.peers = peers
                weakSelf.tableView.reloadData()
            }
        }
    }
    
    private func reloadSelections() {
        tableView.indexPathsForSelectedRows?.forEach({ (indexPath) in
            tableView.deselectRow(at: indexPath, animated: true)
        })
        if isSearching {
            for (row, peer) in searchResults.enumerated() where selections.contains(peer) {
                let indexPath = IndexPath(row: row, section: 0)
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            }
        } else {
            for (section, peers) in peers.enumerated() {
                for (row, peer) in peers.enumerated() where selections.contains(peer) {
                    let indexPath = IndexPath(row: row, section: section)
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                }
            }
        }
    }
    
}
