import UIKit
import MixinServices

class GroupCallMemberDataSource: NSObject {
    
    static let membersDidChangeNotification = Notification.Name("one.mixin.messenger.GroupCallMemberDataSource.MembersDidChange")
    
    private let conversationId: String
    
    private(set) var invitingMemberUserIds: Set<String>
    private(set) var members: [UserItem] {
        didSet {
            NotificationCenter.default.post(name: Self.membersDidChangeNotification, object: self)
        }
    }
    
    weak var collectionView: UICollectionView? {
        didSet {
            oldValue?.dataSource = nil
            if let collectionView = collectionView {
                collectionView.dataSource = self
                collectionView.reloadData()
            }
        }
    }
    
    init(conversationId: String, members: [UserItem], invitingMemberUserIds: Set<String>) {
        self.conversationId = conversationId
        self.members = members
        self.invitingMemberUserIds = invitingMemberUserIds
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didRemoveZombieMember(_:)),
                                               name: GroupCallMembersManager.didRemoveZombieMemberNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func reportStartInviting(_ members: [UserItem]) {
        let filtered = members.filter { (user) -> Bool in
            !self.members.contains(where: { $0.userId == user.userId })
        }
        for user in filtered {
            // TODO: Update corresponding cell if existed
            invitingMemberUserIds.insert(user.userId)
        }
        let indexPaths = (self.members.count..<(self.members.count + filtered.count))
            .map({ IndexPath(item: $0, section: 0) })
        self.members.append(contentsOf: filtered)
        collectionView?.insertItems(at: indexPaths)
    }
    
    func reportMemberDidConnected(_ member: UserItem) {
        invitingMemberUserIds.remove(member.userId)
        if let item = members.firstIndex(where: { $0.userId == member.userId }) {
            let indexPath = IndexPath(item: item, section: 0)
            collectionView?.reloadItems(at: [indexPath])
        } else {
            let indexPath = IndexPath(item: members.count, section: 0)
            members.append(member)
            collectionView?.insertItems(at: [indexPath])
        }
    }
    
    func reportMemberWithIdDidDisconnected(_ id: String) {
        invitingMemberUserIds.remove(id)
        if let item = members.firstIndex(where: { $0.userId == id }) {
            let indexPath = IndexPath(item: item, section: 0)
            members.remove(at: item)
            collectionView?.deleteItems(at: [indexPath])
        }
    }
    
    @objc private func didRemoveZombieMember(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        guard let conversationId = userInfo[GroupCallMembersManager.conversationIdUserInfoKey] as? String else {
            return
        }
        guard conversationId == self.conversationId else {
            return
        }
        guard let userId = userInfo[GroupCallMembersManager.userIdUserInfoKey] as? String else {
            return
        }
        DispatchQueue.main.async {
            self.reportMemberWithIdDidDisconnected(userId)
        }
    }
    
}

extension GroupCallMemberDataSource: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        members.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.group_call_member, for: indexPath)!
        let member = members[indexPath.item]
        cell.avatarImageView.setImage(with: member)
        cell.connectingView.isHidden = !invitingMemberUserIds.contains(member.userId)
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
}
