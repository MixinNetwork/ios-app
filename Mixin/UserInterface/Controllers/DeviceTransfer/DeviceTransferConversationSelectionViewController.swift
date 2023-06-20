import UIKit
import AVFoundation
import MixinServices

class DeviceTransferConversationSelectionViewController: PeerViewController<MessageReceiver, CheckmarkPeerCell, MessageReceiverSearchResult> {
    
    @IBOutlet weak var operationAllButton: UIButton!
    @IBOutlet weak var showSelectedButton: UIButton!
    
    private var toolbarView: UIView!
    private var filter: DeviceTransferFilter!
    
    private var selections = [MessageReceiver]() {
        didSet {
            container?.rightButton.isEnabled = selections.count > 0
            let title = !models.isEmpty && models.count == selections.count
                ? R.string.localizable.deselect_all()
                : R.string.localizable.select_all()
            operationAllButton.setTitle(title, for: .normal)
            let color = selections.isEmpty ? R.color.text_accessory() : R.color.theme()
            showSelectedButton.setTitleColor(color, for: .normal)
            showSelectedButton.setTitle(R.string.localizable.show_selected(selections.count), for: .normal)
            showSelectedButton.isEnabled = !selections.isEmpty
        }
    }
    
    class func instance(filter: DeviceTransferFilter) -> UIViewController {
        let controller = DeviceTransferConversationSelectionViewController()
        controller.filter = filter
        return ContainerViewController.instance(viewController: controller, title: R.string.localizable.conversations())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableViewBottomConstraint.isActive = false
        toolbarView = R.nib.deviceTransferConversationSelectionToolbarView(owner: self)
        view.addSubview(toolbarView)
        toolbarView.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(tableView.snp.bottom)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        tableView.allowsMultipleSelection = true
        showSelectedButton.titleLabel?.font = .monospacedDigitSystemFont(ofSize: 16, weight: .regular)
    }
    
    override func initData() {
        initDataOperation.addExecutionBlock { [weak self] in
            guard let self else {
                return
            }
            let conversations = ConversationDAO.shared.conversationList()
                .compactMap(MessageReceiver.init)
            let selections: [MessageReceiver]
            switch filter.conversation {
            case .all:
                selections = conversations
            case .designated(let conversationIDs):
                selections = conversations.filter { conversationIDs.contains($0.conversationId) }
            }
            DispatchQueue.main.sync {
                self.models = conversations
                self.selections = selections
                self.tableView.reloadData()
                self.reloadTableViewSelections()
            }
        }
        queue.addOperation(initDataOperation)
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 != initDataOperation })
            .forEach({ $0.cancel() })
        let op = BlockOperation()
        let receivers = self.models
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            let uniqueReceivers = Set(receivers.compactMap({ $0 }))
            let searchResults = uniqueReceivers
                .filter { $0.matches(lowercasedKeyword: keyword) }
                .map { MessageReceiverSearchResult(receiver: $0, keyword: keyword) }
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
            cell.render(receiver: models[indexPath.row])
        }
    }
    
    override func reloadTableViewSelections() {
        super.reloadTableViewSelections()
        if isSearching {
            for (index, result) in searchResults.enumerated() {
                guard selections.contains(result.receiver) else {
                    continue
                }
                let indexPath = IndexPath(row: index, section: 0)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        } else {
            updateSelectedRows()
        }
    }
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : models.count
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selections.append(messageReceiver(at: indexPath))
        if !isSearching {
            updateSelectedRows()
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let receiver = messageReceiver(at: indexPath)
        if let index = selections.firstIndex(of: receiver) {
            selections.remove(at: index)
        }
        if !isSearching {
            if let row = models.firstIndex(where: { $0.conversationId == receiver.conversationId }) {
                tableView.deselectRow(at: IndexPath(row: row, section: 0), animated: false)
            }
        }
    }
    
    @IBAction func operationAllAction(_ sender: Any) {
        if selections.count == models.count {
            selections.removeAll()
            for index in 0..<models.count {
                tableView.deselectRow(at: IndexPath(row: index, section: 0), animated: false)
            }
        } else {
            selections = models
            for index in 0..<models.count {
                tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
            }
        }
    }
    
    @IBAction func showSelectedAction(_ sender: Any) {
        let window = DeviceTransferSelectedConversationWindow.instance()
        window.render(selections: selections) { receiver in
            if let index = self.selections.firstIndex(of: receiver) {
                self.selections.remove(at: index)
            }
            if let row = self.models.firstIndex(where: { $0.conversationId == receiver.conversationId }) {
                self.tableView.deselectRow(at: IndexPath(row: row, section: 0), animated: false)
            }
        }
        window.presentPopupControllerAnimated()
    }
    
}

extension DeviceTransferConversationSelectionViewController: ContainerViewControllerDelegate {
    
    func textBarRightButton() -> String? {
        R.string.localizable.save()
    }
    
    func barRightButtonTappedAction() {
        if selections.count == models.count {
            filter.conversation = .all
        } else {
            filter.conversation = .designated(Set(selections.map(\.conversationId)))
        }
        navigationController?.popViewController(animated: true)
    }
    
}

extension DeviceTransferConversationSelectionViewController {
    
    private func messageReceiver(at indexPath: IndexPath) -> MessageReceiver {
        if isSearching {
            return searchResults[indexPath.row].receiver
        } else {
            return models[indexPath.row]
        }
    }
    
    private func updateSelectedRows() {
        assert(!isSearching)
        for (row, receiver) in models.enumerated() where selections.contains(receiver) {
            tableView.selectRow(at: IndexPath(row: row, section: 0), animated: false, scrollPosition: .none)
        }
    }
    
}
