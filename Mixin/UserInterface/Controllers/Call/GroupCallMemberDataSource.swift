import UIKit
import MixinServices

class GroupCallMemberDataSource: NSObject {
    
    private(set) var members: [UserItem]
    private(set) var invitingMemberUserIds: Set<String>
    
    weak var collectionView: UICollectionView? {
        didSet {
            oldValue?.dataSource = nil
            if let collectionView = collectionView {
                collectionView.dataSource = self
                collectionView.reloadData()
            }
        }
    }
    
    init(members: [UserItem], invitingMemberUserIds: Set<String>) {
        self.members = members
        self.invitingMemberUserIds = invitingMemberUserIds
        super.init()
    }
    
    func reportStartInviting(_ members: [UserItem]) {
        let filtered = members.filter { (user) -> Bool in
            !members.contains(where: { $0.userId == user.userId })
        }
        for user in filtered {
            // TODO: Update corresponding cell if existed
            invitingMemberUserIds.insert(user.userId)
        }
        let indexPaths = (self.members.count..<(self.members.count + filtered.count))
            .map({ IndexPath(item: $0, section: 1) })
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
