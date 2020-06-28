import UIKit
import MixinServices

class GroupCallMemberDataSource: NSObject {
    
    private(set) var connected: [UserItem]
    private(set) var connecting: [UserItem]
    
    weak var collectionView: UICollectionView? {
        didSet {
            oldValue?.dataSource = nil
            if let collectionView = collectionView {
                collectionView.dataSource = self
                collectionView.reloadData()
            }
        }
    }
    
    var allMembers: [UserItem] {
        memberGroups.flatMap({ $0 })
    }
    
    private var memberGroups: [[UserItem]] {
        [connected, connecting]
    }
    
    init(connected: [UserItem], connecting: [UserItem]) {
        self.connected = connected
        self.connecting = connecting
        super.init()
    }
    
    func reportMembersStartedConnecting(_ users: [UserItem]) {
        guard let collectionView = collectionView else {
            return
        }
        let filtered = users.filter { (user) -> Bool in
            !connecting.contains(where: { $0.userId == user.userId })
        }
        let indexPaths = (connecting.count..<(connecting.count + filtered.count))
            .map({ IndexPath(item: $0, section: 1) })
        connecting.append(contentsOf: filtered)
        collectionView.insertItems(at: indexPaths)
    }
    
    func reportMemberDidConnected(_ user: UserItem) {
        guard let collectionView = collectionView else {
            return
        }
        collectionView.performBatchUpdates({
            if !connected.contains(where: { $0.userId == user.userId }) {
                let indexPath = IndexPath(item: self.connected.count, section: 0)
                self.connected.append(user)
                collectionView.insertItems(at: [indexPath])
            }
            if let index = self.connecting.firstIndex(where: { $0.userId == user.userId }) {
                let indexPath = IndexPath(item: index, section: 1)
                self.connecting.remove(at: index)
                collectionView.deleteItems(at: [indexPath])
            }
        }, completion: nil)
    }
    
    func reportMemberWithIdDidDisconnected(_ id: String) {
        guard let collectionView = collectionView else {
            return
        }
        collectionView.performBatchUpdates({
            if let index = self.connected.firstIndex(where: { $0.userId == id }) {
                let indexPath = IndexPath(item: index, section: 0)
                self.connected.remove(at: index)
                collectionView.deleteItems(at: [indexPath])
            }
            if let index = self.connecting.firstIndex(where: { $0.userId == id }) {
                let indexPath = IndexPath(item: index, section: 1)
                self.connecting.remove(at: index)
                collectionView.deleteItems(at: [indexPath])
            }
        }, completion: nil)
    }
    
}

extension GroupCallMemberDataSource: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        memberGroups[section].count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.group_call_member, for: indexPath)!
        let member = memberGroups[indexPath.section][indexPath.row]
        cell.avatarImageView.setImage(with: member)
        cell.connectingView.isHidden = indexPath.section == 0
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        memberGroups.count
    }
    
}
