import UIKit

class PeerSelectionViewController: UIViewController, ContainerViewControllerDelegate {
    
    let tableView = UITableView()
    let searchBoxView = SearchBoxView(frame: CGRect(x: 0, y: 0, width: 375, height: 40))
    
    var allowsMultipleSelection: Bool {
        return true
    }
    
    var tableRowHeight: CGFloat {
        return 70
    }
    
    private let queue = OperationQueue()
    
    private var headerTitles = [String]()
    private var peers = [[Peer]]()
    private var searchResults = [PeerSearchResult]()
    private var selections = Set<Peer>() {
        didSet {
            container?.rightButton.isEnabled = selections.count > 0
        }
    }
    private var sortedSelections = [Peer]()
    private var loadAllPeersOperation: BlockOperation!
    private var lastKeyword: String?
    
    private var trimmedLowercaseKeyword: String {
        if let text = searchBoxView.textField.text {
            return text.trimmingCharacters(in: .whitespaces).lowercased()
        } else {
            return ""
        }
    }
    
    private var isSearching: Bool {
        return !searchBoxView.textField.text.isNilOrEmpty
    }
    
    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        view.addSubview(searchBoxView)
        view.addSubview(tableView)
        searchBoxView.snp.makeConstraints { (make) in
            make.top.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(40)
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
        tableView.allowsMultipleSelection = allowsMultipleSelection
        tableView.rowHeight = tableRowHeight
        tableView.separatorColor = UIColor.white
        tableView.separatorStyle = .none
        tableView.register(R.nib.peerCell)
        tableView.register(GeneralTableViewHeader.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 15))
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        queue.maxConcurrentOperationCount = 1
        loadAllPeersOperation = BlockOperation()
        loadAllPeersOperation.addExecutionBlock { [weak self] in
            let contacts = UserDAO.shared.contacts()
            guard let weakSelf = self else {
                return
            }
            let catalogedPeers = weakSelf.catalogedPeers(contacts: contacts)
            DispatchQueue.main.sync {
                weakSelf.headerTitles = catalogedPeers.titles
                weakSelf.peers = catalogedPeers.peers
                weakSelf.tableView.reloadData()
            }
        }
        queue.addOperation(loadAllPeersOperation)
    }
    
    @objc func search(_ sender: Any) {
        searchResults = []
        tableView.reloadData()
        reloadSelections()
        let keyword = trimmedLowercaseKeyword
        guard !keyword.isEmpty, keyword != lastKeyword else {
            return
        }
        queue.operations
            .filter { $0 != loadAllPeersOperation }
            .forEach { $0.cancel() }
        let op = BlockOperation()
        let peers = self.peers
        op.addExecutionBlock { [unowned op, weak self] in
            guard !op.isCancelled else {
                return
            }
            var unique = Set<Peer>()
            let results = peers.flatMap { $0 }
                .filter { (peer) -> Bool in
                    if peer.name.lowercased().contains(keyword) {
                        return true
                    } else if case let .user(user) = peer.item {
                        if user.identityNumber.contains(keyword) {
                            return true
                        } else if let phone = user.phone {
                            return phone.contains(keyword)
                        }
                    }
                    return false
                }
                .filter { unique.insert($0).inserted }
                .map { PeerSearchResult(peer: $0, keyword: keyword) }
            guard !op.isCancelled else {
                return
            }
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.searchResults = results
                weakSelf.tableView.reloadData()
                weakSelf.reloadSelections()
                weakSelf.lastKeyword = keyword
            }
        }
        queue.addOperation(op)
    }
    
    func work(selections: [Peer]) {
        
    }
    
    func catalogedPeers(contacts: [UserItem]) -> (titles: [String], peers: [[Peer]]) {
        return ([], [])
    }
    
    func popToConversationWithLastSelection() {
        if let peer = sortedSelections.last {
            let vc: ConversationViewController
            switch peer.item {
            case .group(let conversation):
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
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
        let (peer, description) = peerAndDescription(at: indexPath)
        cell.render(peer: peer, description: description)
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
        header.labelTopConstraint.constant = 10
        header.label.text = headerTitles[section]
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isSearching {
            return .leastNormalMagnitude
        } else if !headerTitles.isEmpty {
            return peers[section].isEmpty ? .leastNormalMagnitude : 36
        } else {
            return .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let (peer, _) = peerAndDescription(at: indexPath)
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
        let (peer, _) = peerAndDescription(at: indexPath)
        selections.remove(peer)
        if let index = sortedSelections.firstIndex(of: peer) {
            sortedSelections.remove(at: index)
        }
        reloadSelections()
    }
    
}

extension PeerSelectionViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if searchBoxView.textField.isFirstResponder {
            searchBoxView.textField.resignFirstResponder()
        }
    }
    
}

extension PeerSelectionViewController {
    
    private enum ReuseId {
        static let header = "header"
    }
    
    private func peerAndDescription(at indexPath: IndexPath) -> (Peer, NSAttributedString?) {
        if isSearching {
            let result = searchResults[indexPath.row]
            return (result.peer, result.description)
        } else {
            return (peers[indexPath.section][indexPath.row], nil)
        }
    }
    
    private func reloadSelections() {
        tableView.indexPathsForSelectedRows?.forEach({ (indexPath) in
            tableView.deselectRow(at: indexPath, animated: true)
        })
        if isSearching {
            for (row, result) in searchResults.enumerated() where selections.contains(result.peer) {
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
