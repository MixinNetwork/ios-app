import UIKit

class AddMemberViewController_Legacy: PeerSelectionViewController_Legacy {
    
    private let maxMembersCount = 256
    
    private var conversationId: String? = nil
    private var alreadyInGroupUserIds = Set<String>()
    
    private var rightButton: StateResponsiveButton {
        return container!.rightButton
    }
    
    private var isAppendingMembersToAnExistedGroup: Bool {
        return conversationId != nil
    }
    
    class func instance(appendingMembersToConversationId conversationId: String? = nil) -> UIViewController {
        let vc = AddMemberViewController_Legacy()
        vc.conversationId = conversationId
        return ContainerViewController.instance(viewController: vc, title: Localized.ACTION_SEND_TO)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        container?.subtitleLabel.isHidden = false
        container?.titleLabel.text = R.string.localizable.group_navigation_title_add_member()
    }
    
    override func initData() {
        let contacts = UserDAO.shared.contacts()
        let catalogedPeers = self.catalogedPeers(contacts: contacts)
        let participantUserIds: Set<String>
        if let conversationId = conversationId {
            let participants = ParticipantDAO.shared.participants(conversationId: conversationId)
            participantUserIds = Set(participants.map({ $0.userId }))
        } else {
            participantUserIds = Set()
        }
        DispatchQueue.main.sync {
            headerTitles = catalogedPeers.titles
            peers = catalogedPeers.peers
            alreadyInGroupUserIds = participantUserIds
            updateSubtitle()
            tableView.reloadData()
        }
    }
    
    override func textBarRightButton() -> String? {
        if isAppendingMembersToAnExistedGroup {
            return R.string.localizable.action_done()
        } else {
            return R.string.localizable.action_next()
        }
    }
    
    override func selectionsDidChange() {
        super.selectionsDidChange()
        updateSubtitle()
    }
    
    override func shouldSelect(peer: Peer_Legacy, at indexPath: IndexPath) -> Bool {
        if selections.contains(peer) {
            return true
        } else {
            if let userId = peer.user?.userId, alreadyInGroupUserIds.contains(userId), let cell = tableView.cellForRow(at: indexPath) as? PeerCell_Legacy {
                cell.forceSelected = true
            }
            return false
        }
    }
    
    override func catalogedPeers(contacts: [UserItem]) -> (titles: [String], peers: [[Peer_Legacy]]) {
        
        class ObjcAccessiblePeer: NSObject {
            @objc let fullName: String
            let peer: Peer_Legacy
            
            init(user: UserItem) {
                self.fullName = user.fullName
                self.peer = Peer_Legacy(user: user)
                super.init()
            }
        }
        
        let objcAccessibleUsers = contacts.map(ObjcAccessiblePeer.init)
        let (titles, objcUsers) = UILocalizedIndexedCollation.current()
            .catalogue(objcAccessibleUsers, usingSelector: #selector(getter: ObjcAccessiblePeer.fullName))
        let peers = objcUsers.map({ $0.map({ $0.peer }) })
        return (titles, peers)
    }
    
    override func work(selections: [Peer_Legacy]) {
        let users = selections.compactMap({ $0.user })
        if let conversationId = conversationId {
            rightButton.isBusy = true
            let ids = users.map { $0.userId }
            ConversationAPI.shared.addParticipant(conversationId: conversationId, participantUserIds: ids, completion: { [weak self] (result) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.rightButton.isBusy = false
                switch result {
                case .success:
                    weakSelf.navigationController?.popViewController(animated: true)
                case let .failure(error):
                    showHud(style: .error, text: error.localizedDescription)
                }
            })
        } else {
            let members = users.map(GroupUser.init)
            let vc = NewGroupViewController.instance(members: members)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        let (peer, _) = peerAndDescription(at: indexPath)
        if let userId = peer.user?.userId, alreadyInGroupUserIds.contains(userId), let cell = cell as? PeerCell_Legacy {
            cell.forceSelected = true
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let (peer, _) = peerAndDescription(at: indexPath)
        if let userId = peer.user?.userId, alreadyInGroupUserIds.contains(userId) {
            tableView.deselectRow(at: indexPath, animated: false)
        } else {
            super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }
    
    private func updateSubtitle() {
        let subtitle = "\(selections.count + alreadyInGroupUserIds.count)/\(maxMembersCount)"
        container?.subtitleLabel.text = subtitle
    }
    
}
