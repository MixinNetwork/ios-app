import UIKit
import MixinServices

class GroupCallMemberPickerContentViewController: UserItemPeerViewController<CheckmarkPeerCell> {
    
    override class var showSelectionsOnTop: Bool {
        true
    }
    
    private let conversationId: String
    private let callButtonSize = CGSize(width: 50, height: 50)
    
    private lazy var callButton = UIButton()
    
    private var selections = [UserItem]()
    
    init(conversationId: String) {
        self.conversationId = conversationId
        let nib = R.nib.peerView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.allowsMultipleSelection = true
        collectionView.dataSource = self
        callButton.backgroundColor = R.color.background_selection()
        callButton.setImage(R.image.call.ic_minimized_call(), for: .normal)
        callButton.tintColor = .theme
        callButton.layer.cornerRadius = callButtonSize.width / 2
        callButton.clipsToBounds = true
        callButton.addTarget(self, action: #selector(makeCall), for: .touchUpInside)
        centerWrapperView.addSubview(callButton)
        callButton.snp.makeConstraints { (make) in
            make.size.equalTo(callButtonSize)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(7)
        }
        collectionView.snp.updateConstraints { (make) in
            make.trailing.equalToSuperview().offset(-78)
        }
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
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = userItem(at: indexPath)
        let indexPath = IndexPath(item: selections.count, section: 0)
        selections.append(item)
        collectionView.insertItems(at: [indexPath])
        collectionView.scrollToItem(at: indexPath, at: .right, animated: true)
        setCollectionViewHidden(false, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let item = userItem(at: indexPath)
        if let index = selections.firstIndex(where: { $0.userId == item.userId }) {
            selections.remove(at: index)
            let indexPath = IndexPath(item: index, section: 0)
            collectionView.deleteItems(at: [indexPath])
            setCollectionViewHidden(selections.isEmpty, animated: true)
        }
    }
    
    @objc func makeCall() {
        
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
        selections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.selected_peer, for: indexPath)!
        let item = selections[indexPath.row]
        cell.render(item: item)
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
        let deselected = selections[indexPath.row]
        if isSearching {
            if let item = searchResults.firstIndex(where: { $0.user.userId == deselected.userId }) {
                let indexPath = IndexPath(item: item, section: 0)
                tableView.deselectRow(at: indexPath, animated: true)
                tableView(tableView, didDeselectRowAt: indexPath)
            }
        } else {
            if let item = models.firstIndex(where: { $0.userId == deselected.userId }) {
                let indexPath = IndexPath(item: item, section: 0)
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
            self.conversationId = viewController.conversationId
        }
        
        override func main() {
            guard !isCancelled else {
                return
            }
            let participants = ParticipantDAO.shared
                .getParticipants(conversationId: conversationId)
                .filter { !$0.isBot && $0.relationship != Relationship.ME.rawValue }
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
