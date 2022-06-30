import Foundation
import CoreSpotlight
import MobileCoreServices
import MixinServices

class SpotlightManager: NSObject {
    
    private enum State: String {
        case indexed
        case deleted
        
        var data: Data { rawValue.data(using: .utf8)! }
    }
    
    static let shared = SpotlightManager()
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.queue.spotlight")
    private let index = CSSearchableIndex(name: "one.mixin.messenger")
    
    override init() {
        super.init()
        index.indexDelegate = self
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(cleanupSearchableItems), name: LoginManager.didLogoutNotification, object: nil)
        center.addObserver(self, selector: #selector(refreshSearchableItems), name: UserDAO.usersDidChangeNotification, object: nil)
    }
    
    func contiune(_ activity: NSUserActivity) {
        guard
            let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
            let userId = userId(from: identifier),
            let user = UserDAO.shared.getUser(userId: userId)
        else {
            return
        }
        let presentUserProfileController = {
            let controller = UserProfileViewController(user: user)
            UIApplication.homeContainerViewController?.present(controller, animated: true, completion: nil)
        }
        if let presentedViewController = UIApplication.homeContainerViewController?.presentedViewController {
            if let profile = presentedViewController as? UserProfileViewController, profile.user.userId == user.userId {
                return
            }
            presentedViewController.dismiss(animated: true) {
                presentUserProfileController()
            }
        } else {
            presentUserProfileController()
        }
    }
    
    func indexIfNeeded() {
        index.fetchLastClientState { data, error in
            if let error = error {
                Logger.general.error(category: "SpotlightManager", message: "Failed to fetch last client state: \(error)")
            } else if data != State.indexed.data {
                self.indexSearchableItems()
            }
        }
    }
    
    @objc private func refreshSearchableItems(_ notification: Notification) {
        guard let userResponses = notification.userInfo?[UserDAO.UserInfoKey.users] as? [UserResponse] else {
            return
        }
        queue.async {
            var needsDeletedItems = [String]()
            var needsIndexedItems = [CSSearchableItem]()
            for response in userResponses {
                let user = UserItem.createUser(from: response)
                guard user.isBot else {
                    continue
                }
                if user.relationship == Relationship.FRIEND.rawValue {
                    if let item = self.searchableItem(userId: user.userId, name: user.fullName, biography: user.biography, avatarUrl: user.avatarUrl) {
                        needsIndexedItems.append(item)
                    }
                } else {
                    let identifiers = self.uniqueIdentifier(for: user.userId)
                    needsDeletedItems.append(identifiers)
                }
            }
            self.index.indexSearchableItems(needsIndexedItems)
            self.index.deleteSearchableItems(withIdentifiers: needsDeletedItems)
        }
    }
    
    @objc private func cleanupSearchableItems() {
        queue.async {
            self.index.beginBatch()
            self.index.deleteAllSearchableItems()
            self.index.endBatch(withClientState: State.deleted.data)
        }
    }
    
    private func indexSearchableItems(_ userIds: [String] = []) {
        queue.async {
            let users: [User]
            if userIds.isEmpty {
                users = UserDAO.shared.getAppUsers()
            } else {
                users = UserDAO.shared.getUsers(withAppIds: userIds)
            }
            let searchableItems = users.compactMap {
                self.searchableItem(userId: $0.userId, name: $0.fullName, biography: $0.biography, avatarUrl: $0.avatarUrl)
            }
            self.index.beginBatch()
            self.index.indexSearchableItems(searchableItems)
            self.index.endBatch(withClientState: State.indexed.data)
        }
    }
    
    private func searchableItem(userId: String, name: String?, biography: String?, avatarUrl: String?) -> CSSearchableItem? {
        guard let name = name else {
            return nil
        }
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        attributeSet.title = name
        attributeSet.keywords = [name]
        if let biography = biography {
            attributeSet.contentDescription = biography
        }
        if let avatarUrl = avatarUrl {
            attributeSet.thumbnailURL = URL(string: avatarUrl)
        }
        let uniqueIdentifier = uniqueIdentifier(for: userId)
        let domainIdentifier = "one.mixin.messenger.spotlight.users"
        return CSSearchableItem(uniqueIdentifier: uniqueIdentifier, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
    }
    
    private func uniqueIdentifier(for userId: String) -> String {
        "one.mixin.messenger.spotlight.user.\(userId)"
    }
    
    private func userId(from identifier: String) -> String? {
        identifier.components(separatedBy: ".").last
    }
    
}

extension SpotlightManager: CSSearchableIndexDelegate {
    
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        let userIds = identifiers.compactMap(userId(from:))
        indexSearchableItems(userIds)
        acknowledgementHandler()
    }
    
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        indexSearchableItems()
        acknowledgementHandler()
    }
    
}
