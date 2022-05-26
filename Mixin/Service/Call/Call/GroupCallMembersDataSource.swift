import Foundation
import MixinServices

// This is the data source of visible members in a group call

fileprivate let debugWithNumerousMembers = false

class GroupCallMembersDataSource: NSObject {
    
    static let membersCountDidChangeNotification = Notification.Name("one.mixin.messenger.GroupCallMembersDataSource.MembersCountDidChange")
    
    var collectionView: UICollectionView? {
        willSet {
            assert(Thread.isMainThread)
            collectionView?.dataSource = nil
        }
        didSet {
            assert(Thread.isMainThread)
            guard let collectionView = collectionView else {
                return
            }
            collectionView.dataSource = self
        }
    }
    
    private(set) var members: [Member] {
        didSet {
            assert(Thread.isMainThread)
            if members.count != oldValue.count {
                NotificationCenter.default.post(name: Self.membersCountDidChangeNotification, object: self)
            }
        }
    }
    
    private let conversationId: String
    
    private var indices: [String: Int] // Map user id to member's index to improve responsiveness
    private var inviteeUserIds: Set<String>
    
    init(conversationId: String, inviters: [UserItem], invitees: [UserItem]) {
        var memberIds: [String]
        if Thread.isMainThread {
            memberIds = CallService.shared.membersManager.memberIds(forConversationWith: conversationId)
        } else {
            memberIds = CallService.shared.membersManager.requestMemberIds(forConversationWith: conversationId)
        }
        for invitee in invitees where !memberIds.contains(invitee.userId) {
            memberIds.append(invitee.userId)
        }
        for inviter in inviters where !memberIds.contains(inviter.userId) {
            memberIds.insert(inviter.userId, at: 0)
        }
        
        var memberItems = UserDAO.shared.getUsers(with: memberIds)
        if let index = memberItems.firstIndex(where: { $0.userId == myUserId }) {
            let me = memberItems.remove(at: index)
            memberItems.insert(me, at: 0)
        } else if let account = LoginManager.shared.account {
            let me = UserItem.createUser(from: account)
            memberItems.insert(me, at: 0)
        }
        
        let allMembers = memberItems.map { item in
            Member(item: item, status: nil, isConnected: false)
        }
        let indices = allMembers.enumerated().reduce(into: [:]) { map, enumerated in
            map[enumerated.element.item.userId] = enumerated.offset
        }
        
        self.conversationId = conversationId
        self.members = allMembers
        self.indices = indices
        self.inviteeUserIds = Set(invitees.map(\.userId))
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(membersDidChange(_:)), name: GroupCallMembersManager.membersDidChangeNotification, object: nil)
    }
    
}

// MARK: - Member Access
extension GroupCallMembersDataSource {
    
    /// Returns true on overwritten or appending, false on no operation
    @discardableResult
    func addMember(_ member: Member, onConflict resolve: ConflictResolve) -> Bool {
        assert(Thread.isMainThread)
        if let index = indices[member.item.userId] {
            switch resolve {
            case .overwrite:
                members[index] = member
                if let cell = cellForMember(at: index) {
                    cell.connectingView.isHidden = member.isConnected
                    cell.status = member.status
                }
                if member.isConnected {
                    inviteeUserIds.remove(member.item.userId)
                }
                return true
            case .discard:
                return false
            }
        } else {
            let index = members.count
            members.append(member)
            indices[member.item.userId] = index
            if let collectionView = collectionView {
                let indexPath = indexPathForMember(at: index)
                collectionView.insertItems(at: [indexPath])
            }
            if member.isConnected {
                inviteeUserIds.remove(member.item.userId)
            }
            return true
        }
    }
    
    func removeMember(with userId: String, onlyIfNotConnected: Bool) {
        assert(Thread.isMainThread)
        guard let indexToDelete = indices[userId] else {
            return
        }
        guard !members[indexToDelete].isConnected || !onlyIfNotConnected else {
            return
        }
        let indexPath = indexPathForMember(at: indexToDelete)
        indices[userId] = nil
        members.remove(at: indexToDelete)
        indices = indices.mapValues { index in
            if index > indexToDelete {
                return index - 1
            } else {
                return index
            }
        }
        collectionView?.deleteItems(at: [indexPath])
    }
    
    func updateMembers(with audioLevels: [String: Double]) {
        assert(Thread.isMainThread)
        for (index, member) in members.enumerated() {
            let oldStatus = member.status
            let audioLevel = audioLevels[member.item.userId] ?? 0
            member.update(with: audioLevel)
            if member.status != oldStatus {
                let indexPath = indexPathForMember(at: index)
                if let cell = collectionView?.cellForItem(at: indexPath) as? CallMemberCell {
                    cell.status = member.status
                }
            }
        }
    }
    
    func setMember(with userId: String, isTrackDisabled: Bool) {
        assert(Thread.isMainThread)
        guard let index = indices[userId] else {
            return
        }
        guard index >= 0 && index < members.count else {
            Logger.call.error(category: "GroupCallMembersDataSource", message: "Invalid index for: \(userId)")
            assertionFailure()
            return
        }
        let member = members[index]
        assert(member.item.userId == userId)
        member.status = isTrackDisabled ? .isTrackDisabled : nil
        if let cell = cellForMember(at: index) {
            cell.status = member.status
        }
    }
    
    func setMember(with userId: String, isConnected: Bool) {
        assert(Thread.isMainThread)
        guard let index = indices[userId] else {
            Logger.call.warn(category: "GroupCallMembersDataSource", message: "Reports absent member connected: \(userId)")
            DispatchQueue.global().async {
                guard let item = UserDAO.shared.getUser(userId: userId) else {
                    return
                }
                let member = Member(item: item, status: nil, isConnected: true)
                DispatchQueue.main.async {
                    self.addMember(member, onConflict: .overwrite)
                }
            }
            return
        }
        guard index >= 0 && index < members.count else {
            Logger.call.error(category: "GroupCallMembersDataSource", message: "Invalid index for: \(userId)")
            assertionFailure()
            return
        }
        let member = members[index]
        assert(member.item.userId == userId)
        member.isConnected = isConnected
        if let cell = cellForMember(at: index) {
            cell.connectingView.isHidden = isConnected
        }
        if member.isConnected {
            inviteeUserIds.remove(member.item.userId)
        }
    }
    
    func member(at indexPath: IndexPath) -> Member? {
        assert(Thread.isMainThread)
        guard indexPath.item > 0 else {
            // Add member button
            return nil
        }
        let index: Int
        if debugWithNumerousMembers {
            index = (indexPath.item - 1) % members.count
        } else {
            index = indexPath.item - 1
        }
        if index < members.count {
            return members[index]
        } else {
            return nil
        }
    }
    
}

// MARK: - Invitee Access
extension GroupCallMembersDataSource {
    
    func reportInviting(with userItems: [UserItem]) {
        assert(Thread.isMainThread)
        let insertedUserIds: [String] = userItems.compactMap { item in
            let member = Member(item: item, status: nil, isConnected: false)
            return addMember(member, onConflict: .discard) ? item.userId : nil
        }
        inviteeUserIds.formUnion(insertedUserIds)
    }
    
    func reportStopInviting(with userId: String) {
        assert(Thread.isMainThread)
        inviteeUserIds.remove(userId)
        removeMember(with: userId, onlyIfNotConnected: true)
    }
    
}

// MARK: - Definitions
extension GroupCallMembersDataSource {
    
    class Member {
        
        enum Status {
            case isSpeaking
            case isTrackDisabled
        }
        
        let item: UserItem
        
        var status: Status?
        var isConnected: Bool
        
        init(item: UserItem, status: Status?, isConnected: Bool) {
            self.item = item
            self.status = status
            self.isConnected = isConnected
        }
        
        func update(with audioLevel: Double) {
            switch status {
            case .isTrackDisabled:
                break
            case .isSpeaking, .none:
                if audioLevel > 0.01 {
                    status = .isSpeaking
                } else {
                    status = nil
                }
            }
        }
        
    }
    
    enum ConflictResolve {
        case overwrite
        case discard
    }
    
}

// MARK: - UICollectionViewDataSource
extension GroupCallMembersDataSource: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assert(collectionView == self.collectionView)
        if debugWithNumerousMembers {
            return (members.count * 10) + 1
        } else {
            return members.count + 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        assert(collectionView == self.collectionView)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.call_member, for: indexPath)!
        if indexPath.item == 0 {
            cell.avatarWrapperView.backgroundColor = R.color.button_background_secondary()
            cell.avatarImageView.imageView.contentMode = .center
            cell.avatarImageView.image = R.image.ic_title_add()
            cell.connectingView.isHidden = true
            cell.label.text = R.string.localizable.add()
        } else {
            cell.avatarWrapperView.backgroundColor = .background
            cell.avatarImageView.imageView.contentMode = .scaleAspectFill
            if let member = self.member(at: indexPath) {
                cell.avatarImageView.setImage(with: member.item)
                cell.connectingView.isHidden = member.isConnected
                cell.label.text = member.item.fullName
                cell.status = member.status
            }
        }
        cell.hasBiggerLayout = false
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        assert(collectionView == self.collectionView) // Set self.collectionView = x instead of x.dataSource = self
        return 1
    }
    
}

// MARK: - Private works
extension GroupCallMembersDataSource {
    
    @objc private func membersDidChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let conversationId = userInfo[GroupCallMembersManager.UserInfoKey.conversationId] as? String,
            conversationId == self.conversationId,
            let inCallIds = userInfo[GroupCallMembersManager.UserInfoKey.userIds] as? [String]
        else {
            return
        }
        let memberIds = members.map(\.item.userId)
        let idsToRemove = memberIds.filter { id in
            !inCallIds.contains(id) && !inviteeUserIds.contains(id) && id != myUserId
        }
        guard !idsToRemove.isEmpty else {
            return
        }
        Logger.call.info(category: "GroupCallMembersDataSource", message: "Removing members by manager change: \(idsToRemove)")
        for id in idsToRemove {
            removeMember(with: id, onlyIfNotConnected: false)
        }
    }
    
    private func indexPathForMember(at index: Int) -> IndexPath {
        IndexPath(row: index + 1, section: 0) // 1 for add button
    }
    
    private func cellForMember(at index: Int) -> CallMemberCell? {
        assert(Thread.isMainThread)
        guard let collectionView = collectionView else {
            return nil
        }
        let indexPath = indexPathForMember(at: index)
        let cell = collectionView.cellForItem(at: indexPath)
        return cell as? CallMemberCell
    }
    
}
