import UIKit

class SearchConversationViewController: UIViewController, SearchableViewController {
    
    @IBOutlet weak var navigationTitleLabel: UILabel!
    @IBOutlet weak var navigationSubtitleLabel: UILabel!
    @IBOutlet weak var navigationIconView: NavigationAvatarIconView!
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var tableView: UITableView!
    
    var inheritedKeyword = ""
    
    var searchTextField: UITextField {
        return searchBoxView.textField
    }
    
    private let queue = OperationQueue()
    private let messageCountPerPage = 50
    private let loadMoreMessageThreshold = 5 // Distance to bottom
    private let loadConversationOp = BlockOperation()
    
    private var conversationId = ""
    private var conversation: ConversationItem?
    private var messages = [[SearchResult]]()
    private var didLoadAllMessages = false
    
    deinit {
        queue.cancelAllOperations()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchTextField.text = inheritedKeyword
        searchTextField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        tableView.register(R.nib.searchResultCell)
        tableView.dataSource = self
        tableView.delegate = self
        let conversationId = self.conversationId
        loadConversationOp.addExecutionBlock { [weak self] in
            let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId)
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.conversation = conversation
            }
        }
        queue.addOperation(loadConversationOp)
        reloadMessages(keyword: inheritedKeyword)
    }
    
    func load(searchResult: SearchResult) {
        switch searchResult.target {
        case let .searchMessageWithGroup(conversationId):
            self.conversationId = conversationId
            navigationIconView.setGroupImage(with: searchResult.iconUrl)
        case let .searchMessageWithContact(conversationId, userId, userFullName):
            self.conversationId = conversationId
            navigationIconView.setImage(with: searchResult.iconUrl, userId: userId, name: userFullName)
        default:
            break
        }
        navigationTitleLabel.text = searchResult.title?.string
        navigationSubtitleLabel.text = searchResult.description?.string
    }
    
    @objc func searchAction(_ sender: Any) {
        queue.operations
            .filter({ $0 != loadConversationOp })
            .forEach({ $0.cancel() })
        let keyword = self.trimmedLowercaseKeyword
        if keyword.isEmpty {
            messages = []
            tableView.reloadData()
        } else {
            reloadMessages(keyword: keyword)
        }
    }
    
    private func reloadMessages(keyword: String) {
        let conversationId = self.conversationId
        let limit = self.messageCountPerPage
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            let messages = MessageDAO.shared.getMessages(conversationId: conversationId, contentLike: keyword, belowCreatedAt: nil, limit: limit)
            guard !op.isCancelled else {
                return
            }
            DispatchQueue.main.sync {
                guard !op.isCancelled, let weakSelf = self else {
                    return
                }
                weakSelf.messages = [messages]
                weakSelf.didLoadAllMessages = messages.count < limit
                weakSelf.tableView.reloadData()
                weakSelf.tableView.setContentOffset(.zero, animated: false)
            }
        }
        op.addDependency(loadConversationOp)
        queue.addOperation(op)
    }
    
}

extension SearchConversationViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.search_result, for: indexPath)!
        cell.render(result: messages[indexPath.section][indexPath.row])
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return messages.count
    }
    
}

extension SearchConversationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard !didLoadAllMessages && queue.operationCount == 0 else {
            return
        }
        guard indexPath.row >= messageCountPerPage - loadMoreMessageThreshold else {
            return
        }
        guard let last = messages.last?.last, case let .message(_, _, _, _, location) = last.target else {
            return
        }
        let conversationId = self.conversationId
        let keyword = self.inheritedKeyword
        let limit = self.messageCountPerPage
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            let messages = MessageDAO.shared.getMessages(conversationId: conversationId, contentLike: keyword, belowCreatedAt: location, limit: limit)
            guard !op.isCancelled else {
                return
            }
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                let section = IndexSet(integer: weakSelf.messages.count)
                weakSelf.messages.append(messages)
                weakSelf.didLoadAllMessages = messages.count < limit
                weakSelf.tableView.insertSections(section, with: .automatic)
            }
        }
        op.addDependency(loadConversationOp)
        queue.addOperation(op)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let conversation = conversation else {
            return
        }
        guard case let .message(_, id, _, _, _) = messages[indexPath.section][indexPath.row].target else {
            return
        }
        let highlight = ConversationDataSource.Highlight(keyword: inheritedKeyword, messageId: id)
        let vc = ConversationViewController.instance(conversation: conversation, highlight: highlight)
        homeNavigationController?.pushViewController(vc, animated: true)
    }
    
}
