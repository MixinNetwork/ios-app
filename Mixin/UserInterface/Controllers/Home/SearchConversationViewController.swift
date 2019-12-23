import UIKit
import MixinServices

class SearchConversationViewController: UIViewController, HomeSearchViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var tableView: UITableView!
    
    let iconView = NavigationAvatarIconView()
    
    var conversationId = ""
    var conversation: ConversationItem?
    var inheritedKeyword: String?
    var lastKeyword: String?
    
    lazy var navigationTitleLabel: UILabel? = UILabel()
    
    var searchTextField: UITextField! {
        return searchBoxView.textField
    }
    
    var wantsNavigationSearchBox: Bool {
        return false
    }
    
    var navigationSearchBoxInsets: UIEdgeInsets {
        return .zero
    }
    
    private let queue = OperationQueue()
    private let messageCountPerPage = 50
    private let loadMoreMessageThreshold = 5 // Distance to bottom
    private let loadConversationOp = BlockOperation()
    
    private var user: UserItem?
    private var messages = [[MessageSearchResult]]()
    private var didLoadAllMessages = false
    
    convenience init() {
        self.init(nib: R.nib.searchConversationView)
    }
    
    deinit {
        queue.cancelAllOperations()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        queue.maxConcurrentOperationCount = 1
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(profileAction))
        iconView.addGestureRecognizer(tapRecognizer)
        iconView.frame.size = iconView.intrinsicContentSize
        iconView.isUserInteractionEnabled = true
        iconView.hasShadow = true
        prepareNavigationBar()
        searchTextField.text = inheritedKeyword
        searchTextField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        searchTextField.delegate = self
        tableView.register(R.nib.peerCell)
        tableView.dataSource = self
        tableView.delegate = self
        if conversation == nil {
            let conversationId = self.conversationId
            loadConversationOp.addExecutionBlock { [weak self] in
                let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId)
                var user: UserItem?
                if let id = conversation?.ownerId, !id.isEmpty {
                    user = UserDAO.shared.getUser(userId: id)
                }
                DispatchQueue.main.sync {
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.conversation = conversation
                    weakSelf.user = user
                }
            }
            queue.addOperation(loadConversationOp)
        }
        if let keyword = inheritedKeyword {
            reloadMessages(keyword: keyword)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchTextField.resignFirstResponder()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        messages.flatMap({ $0 })
            .forEach({ $0.updateTitleAndDescription() })
        tableView.reloadData()
    }
    
    func prepareNavigationBar() {
        navigationTitleLabel?.setFont(scaledFor: .systemFont(ofSize: 18, weight: .semibold),
                                      adjustForContentSize: true)
        navigationTitleLabel?.textColor = .title
        let rightButton = UIBarButtonItem(customView: iconView)
        rightButton.width = 44
        navigationItem.title = " "
        navigationItem.titleView = navigationTitleLabel
        navigationItem.rightBarButtonItem = rightButton
    }
    
    func pushConversation(viewController: ConversationViewController) {
        homeNavigationController?.pushViewController(viewController, animated: true)
    }
    
    func load(searchResult: SearchResult) {
        conversationId = (searchResult as? MessagesWithinConversationSearchResult)?.conversationId ?? ""
        switch searchResult {
        case is MessagesWithGroupSearchResult:
            iconView.setGroupImage(with: searchResult.iconUrl)
        case let result as MessagesWithUserSearchResult:
            iconView.setImage(with: result.iconUrl, userId: result.userId, name: result.userFullname)
        default:
            break
        }
        navigationTitleLabel?.text = searchResult.title?.string
    }
    
    @objc func searchAction(_ sender: Any) {
        queue.operations
            .filter({ $0 != loadConversationOp })
            .forEach({ $0.cancel() })
        guard let keyword = trimmedLowercaseKeyword else {
            messages = []
            tableView.reloadData()
            lastKeyword = nil
            searchBoxView.isBusy = false
            return
        }
        guard keyword != lastKeyword else {
            return
        }
        reloadMessages(keyword: keyword)
    }
    
    @objc func profileAction() {
        guard let user = user, user.isCreatedByMessenger else {
            return
        }
        let vc = UserProfileViewController(user: user)
        present(vc, animated: true, completion: nil)
    }
    
    private func reloadMessages(keyword: String) {
        let conversationId = self.conversationId
        let limit = self.messageCountPerPage
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            let messages = MessageDAO.shared.getMessages(conversationId: conversationId,
                                                         contentLike: keyword,
                                                         belowMessageId: nil,
                                                         limit: limit)
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
                weakSelf.lastKeyword = keyword
                weakSelf.searchBoxView.isBusy = false
            }
        }
        searchBoxView.isBusy = true
        queue.addOperation(op)
    }
    
}

extension SearchConversationViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}

extension SearchConversationViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
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
        guard let location = messages.last?.last?.messageId else {
            return
        }
        guard let keyword = trimmedLowercaseKeyword else {
            return
        }
        let conversationId = self.conversationId
        let limit = self.messageCountPerPage
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            let messages = MessageDAO.shared.getMessages(conversationId: conversationId,
                                                         contentLike: keyword,
                                                         belowMessageId: location,
                                                         limit: limit)
            guard !op.isCancelled else {
                return
            }
            DispatchQueue.main.sync {
                guard !op.isCancelled, let weakSelf = self else {
                    return
                }
                let section = IndexSet(integer: weakSelf.messages.count)
                weakSelf.messages.append(messages)
                weakSelf.didLoadAllMessages = messages.count < limit
                weakSelf.tableView.insertSections(section, with: .automatic)
            }
        }
        queue.addOperation(op)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let conversation = conversation else {
            return
        }
        guard let keyword = trimmedLowercaseKeyword else {
            return
        }
        let messageId = messages[indexPath.section][indexPath.row].messageId
        let highlight = ConversationDataSource.Highlight(keyword: keyword, messageId: messageId)
        let vc = ConversationViewController.instance(conversation: conversation, highlight: highlight)
        pushConversation(viewController: vc)
    }
    
}
