import UIKit
import MixinServices

class GroupCallMemberPickerContentViewController: UserItemPeerViewController<CheckmarkPeerCell> {
    
    override class var showSelectionsOnTop: Bool {
        true
    }
    
    let cancelButton = UIButton(type: .system)
    let confirmButton = UIButton(type: .system)
    
    var fixedSelections = [UserItem]() {
        didSet {
            fixedUserIds = Set(fixedSelections.map(\.userId))
            collectionView.reloadData()
        }
    }
    
    var appearance: GroupCallMemberPickerViewController.Appearance = .startNewCall {
        didSet {
            let image: UIImage?
            if appearance == .startNewCall {
                image = R.image.call.ic_minimized_call()
                setCollectionViewHidden(true, animated: false)
            } else {
                image = R.image.call.ic_invite_confirm()
                setCollectionViewHidden(false, animated: false)
            }
            confirmButton.setImage(image, for: .normal)
        }
    }
    
    private let conversation: ConversationItem
    private let callButtonSize = CGSize(width: 50, height: 50)
    
    // Automatically updates when fixed selections did set
    private(set) var fixedUserIds = Set<String>()
    
    private var selections = [UserItem]()
    
    init(conversation: ConversationItem) {
        self.conversation = conversation
        let nib = R.nib.peerView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBoxTrailingConstraint.isActive = false
        cancelButton.setTitle(R.string.localizable.dialog_button_cancel(), for: .normal)
        cancelButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16), adjustForContentSize: true)
        cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        cancelButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        view.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { (make) in
            make.centerY.equalTo(searchBoxView)
            make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing)
            make.leading.equalTo(searchBoxView.snp.trailing)
        }
        
        confirmButton.backgroundColor = R.color.background_selection()
        confirmButton.tintColor = .theme
        confirmButton.layer.cornerRadius = callButtonSize.width / 2
        confirmButton.clipsToBounds = true
        confirmButton.addTarget(self, action: #selector(confirm), for: .touchUpInside)
        centerWrapperView.addSubview(confirmButton)
        confirmButton.snp.makeConstraints { (make) in
            make.size.equalTo(callButtonSize)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(7)
        }
        
        collectionView.snp.updateConstraints { (make) in
            make.trailing.equalToSuperview().offset(-78)
        }
        tableView.allowsMultipleSelection = true
        collectionView.dataSource = self
    }
    
    override func initData() {
        let op = ReloadGroupMemberOperation(viewController: self)
        queue.addOperation(op)
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 is SearchOperation })
            .forEach({ $0.cancel() })
        let op = SearchOperation(viewController: self, keyword: keyword)
        queue.addOperation(op)
    }
    
    override func reloadTableViewSelections() {
        super.reloadTableViewSelections()
        if isSearching {
            for (index, result) in searchResults.enumerated() {
                guard selections.contains(where: { $0.userId == result.user.userId }) else {
                    continue
                }
                let indexPath = IndexPath(row: index, section: 0)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        } else {
            for (row, item) in models.enumerated() where selections.contains(where: { $0.userId == item.userId }) {
                let indexPath = IndexPath(row: row, section: 0)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
    }
    
    override func configure(cell: CheckmarkPeerCell, at indexPath: IndexPath) {
        super.configure(cell: cell, at: indexPath)
        let user = userItem(at: indexPath)
        cell.isForceSelected = fixedUserIds.contains(user.userId)
    }
    
    override func setCollectionViewHidden(_ hidden: Bool, animated: Bool) {
        centerWrapperViewBottomConstraint.constant = hidden ? -8 : -13
        centerWrapperViewHeightConstraint.constant = hidden ? 0 : 90
        if animated {
            UIView.animate(withDuration: 0.3, animations: view.layoutIfNeeded)
        } else {
            UIView.performWithoutAnimation(view.layoutIfNeeded)
        }
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        var fixedSelectionsCount = fixedSelections.count
        if appearance == .startNewCall {
            fixedSelectionsCount += 1 // The user himself
        }
        guard fixedSelectionsCount + selections.count < GroupCall.maxNumberOfMembers else {
            let message = R.string.localizable.group_call_selections_reach_limit("\(GroupCall.maxNumberOfMembers)")
            alert(message)
            return nil
        }
        let item = userItem(at: indexPath)
        if fixedUserIds.contains(item.userId) {
            return nil
        } else {
            return indexPath
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = userItem(at: indexPath)
        let indexPath = IndexPath(item: fixedSelections.count + selections.count, section: 0)
        selections.append(item)
        collectionView.insertItems(at: [indexPath])
        collectionView.scrollToItem(at: indexPath, at: .right, animated: true)
        setCollectionViewHidden(false, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let item = userItem(at: indexPath)
        if let index = selections.firstIndex(where: { $0.userId == item.userId }) {
            selections.remove(at: index)
            let indexPath = IndexPath(item: fixedSelections.count + index, section: 0)
            collectionView.deleteItems(at: [indexPath])
            if appearance == .startNewCall {
                setCollectionViewHidden(selections.isEmpty, animated: true)
            }
        }
    }
    
    @objc func confirm() {
        if let parent = parent as? GroupCallMemberPickerViewController {
            parent.onConfirmation?(selections)
        }
        dismiss(animated: true, completion: nil)
    }
    
    @objc func cancelAction() {
        dismiss(animated: true, completion: nil)
    }
    
    private func userItem(at indexPath: IndexPath) -> UserItem {
        if isSearching {
            return searchResults[indexPath.row].user
        } else {
            return models[indexPath.row]
        }
    }
    
}

extension GroupCallMemberPickerContentViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        fixedSelections.count + selections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.selected_peer, for: indexPath)!
        if indexPath.row < fixedSelections.count {
            let item = fixedSelections[indexPath.item]
            cell.render(item: item)
            cell.removeButton.isHidden = true
        } else {
            let item = selections[indexPath.item - fixedSelections.count]
            cell.render(item: item)
            cell.removeButton.isHidden = false
        }
        cell.nameLabel.isHidden = true
        cell.delegate = self
        return cell
    }
    
}

extension GroupCallMemberPickerContentViewController: SelectedPeerCellDelegate {
    
    func selectedPeerCellDidSelectRemove(_ cell: UICollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        let deselected = selections[indexPath.item - fixedSelections.count]
        if isSearching {
            if let item = searchResults.firstIndex(where: { $0.user.userId == deselected.userId }) {
                let indexPath = IndexPath(row: item, section: 0)
                tableView.deselectRow(at: indexPath, animated: true)
                tableView(tableView, didDeselectRowAt: indexPath)
            }
        } else {
            if let item = models.firstIndex(where: { $0.userId == deselected.userId }) {
                let indexPath = IndexPath(row: item, section: 0)
                tableView.deselectRow(at: indexPath, animated: true)
                tableView(tableView, didDeselectRowAt: indexPath)
            }
        }
    }
    
}

extension GroupCallMemberPickerContentViewController {
    
    class ReloadGroupMemberOperation: Operation {
        
        weak var viewController: GroupCallMemberPickerContentViewController?
        
        let conversationId: String
        
        init(viewController: GroupCallMemberPickerContentViewController) {
            self.viewController = viewController
            self.conversationId = viewController.conversation.conversationId
        }
        
        override func main() {
            guard !isCancelled else {
                return
            }
            let fixedUserIds = viewController?.fixedUserIds ?? []
            let participants = ParticipantDAO.shared
                .getParticipants(conversationId: conversationId)
                .filter { !$0.isBot && $0.relationship != Relationship.ME.rawValue }
                .filter { !fixedUserIds.contains($0.userId) }
            DispatchQueue.main.sync {
                guard !isCancelled, let viewController = viewController else {
                    return
                }
                viewController.models = participants
                if let keyword = viewController.searchingKeyword {
                    viewController.search(keyword: keyword)
                } else {
                    viewController.tableView.reloadData()
                }
            }
        }
        
    }
    
}
