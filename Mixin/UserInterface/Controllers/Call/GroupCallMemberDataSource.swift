import UIKit
import MixinServices

class GroupCallMemberDataSource: NSObject {
    
    // Instance of this class is designed to be the data source of member's grid in CallViewController
    // Compared with members stored in GroupCallMembersManager, members here may not actually in the call
    // That is to say, a member which is invited but not yet connected, needs to be shown in the grid, but
    // he's not in the call, therefore you won't find him in GroupCallMembersManager
    
    static let membersDidChangeNotification = Notification.Name("one.mixin.messenger.GroupCallMemberDataSource.MembersDidChange")
    
    private(set) var members: [UserItem] {
        didSet {
            NotificationCenter.default.post(name: Self.membersDidChangeNotification, object: self)
        }
    }
    
    // This var is in sync with members
    private(set) var memberUserIds: Set<String>
    
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
    
    private let conversationId: String
    
    init(conversationId: String, members: [UserItem], invitingMemberUserIds: Set<String>) {
        CallService.shared.log("[GroupCallMemberDataSource] init with members: \(members.map(\.fullName)), inviting: \(invitingMemberUserIds)")
        self.members = members
        self.invitingMemberUserIds = invitingMemberUserIds
        self.conversationId = conversationId
        self.memberUserIds = Set(members.map(\.userId))
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateWithPolledPeers(_:)),
                                               name: GroupCallMembersManager.membersDidChangeNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func reportStartInviting(_ members: [UserItem]) {
        CallService.shared.log("[GroupCallMemberDataSource] start inviting: \(members.map(\.fullName))")
        let filtered = members.filter { (member) -> Bool in
            !self.memberUserIds.contains(member.userId)
        }
        for member in filtered {
            memberUserIds.insert(member.userId)
            invitingMemberUserIds.insert(member.userId)
        }
        if !filtered.isEmpty {
            let indexPaths = (self.members.count..<(self.members.count + filtered.count))
                .map({ IndexPath(item: $0, section: 0) })
            self.members.append(contentsOf: filtered)
            collectionView?.insertItems(at: indexPaths)
        }
    }
    
    func reportMemberDidConnected(_ member: UserItem) {
        CallService.shared.log("[GroupCallMemberDataSource] \(member.fullName) did connected")
        invitingMemberUserIds.remove(member.userId)
        if let item = members.firstIndex(where: { $0.userId == member.userId }) {
            let indexPath = IndexPath(item: item, section: 0)
            UIView.performWithoutAnimation {
                collectionView?.reloadItems(at: [indexPath])
            }
        } else {
            let indexPath = IndexPath(item: members.count, section: 0)
            members.append(member)
            memberUserIds.insert(member.userId)
            collectionView?.insertItems(at: [indexPath])
        }
    }
    
    func reportMemberWithIdDidDisconnected(_ id: String) {
        CallService.shared.log("[GroupCallMemberDataSource] \(id) did disconnected")
        invitingMemberUserIds.remove(id)
        memberUserIds.remove(id)
        if let item = members.firstIndex(where: { $0.userId == id }) {
            let indexPath = IndexPath(item: item, section: 0)
            members.remove(at: item)
            collectionView?.deleteItems(at: [indexPath])
        }
    }
    
    @objc private func updateWithPolledPeers(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        guard let conversationId = userInfo[GroupCallMembersManager.UserInfoKey.conversationId] as? String else {
            return
        }
        guard conversationId == self.conversationId else {
            return
        }
        guard let remoteUserIds = userInfo[GroupCallMembersManager.UserInfoKey.userIds] as? [String] else {
            return
        }
        let remoteIds = Set(remoteUserIds)
        DispatchQueue.main.async {
            for (index, member) in self.members.enumerated().reversed() {
                guard !remoteIds.contains(member.userId) && member.userId != myUserId else {
                    continue
                }
                CallService.shared.log("[GroupCallMemberDataSource] remove zombie: \(member.fullName), at: \(index)")
                self.invitingMemberUserIds.remove(member.userId)
                self.memberUserIds.remove(member.userId)
                self.members.remove(at: index)
                let indexPath = IndexPath(item: index, section: 0)
                self.collectionView?.deleteItems(at: [indexPath])
            }
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
