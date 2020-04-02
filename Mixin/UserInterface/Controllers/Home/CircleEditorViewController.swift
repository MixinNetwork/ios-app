import UIKit
import MixinServices

class CircleEditorViewController: PeerViewController<[CircleMember], CheckmarkPeerCell, CircleMemberSearchResult> {
    
    let collectionViewLayout = UICollectionViewFlowLayout()
    
    var collectionView: UICollectionView!
    
    private var circleId = ""
    private var circleMembers: [CircleMember] = []
    
    class func instance(circleId: String) -> UIViewController {
        let vc = CircleEditorViewController()
        vc.circleId = circleId
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.circle_action_edit_conversations())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        let id = self.circleId
        DispatchQueue.global().async { [weak self] in
            let members = CircleDAO.shared.circleMembers(circleId: id)
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.circleMembers = members
                self.collectionView.reloadData()
            }
        }
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if let container = parent as? ContainerViewController {
            container.leftButton.tintColor = .text
            container.leftButton.setImage(R.image.ic_title_close(), for: .normal)
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
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? 1 : models.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : models[section].count
    }
    
}

extension CircleEditorViewController: ContainerViewControllerDelegate {
    
    func barLeftButtonTappedAction() {
        dismiss(animated: true, completion: nil)
    }
    
    func barRightButtonTappedAction() {
        
    }
    
    func textBarRightButton() -> String? {
        R.string.localizable.action_save()
    }
    
}

extension CircleEditorViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        circleMembers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.circle_member, for: indexPath)!
        let member = circleMembers[indexPath.row]
        cell.render(member: member)
        cell.delegate = self
        return cell
    }
    
}

extension CircleEditorViewController: CircleMemberCellDelegate {
    
    func circleMemberCellDidSelectRemove(_ cell: UICollectionViewCell) {
        
    }
    
}
