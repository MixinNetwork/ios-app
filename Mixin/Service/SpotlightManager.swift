import Foundation
import CoreSpotlight
import MobileCoreServices
import MixinServices

class SpotlightManager {
    
    static let shared = SpotlightManager()
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.queue.spotlight")
    
    init() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(cleanupSearchableItems), name: LoginManager.didLogoutNotification, object: nil)
        center.addObserver(self, selector: #selector(refreshSearchableItems), name: UserDAO.usersDidChangeNotification, object: nil)
    }
    
    func indexSearchableItemsIfNeeded() {
        guard !AppGroupUserDefaults.User.hasIndexedSearchableItems else {
            return
        }
        AppGroupUserDefaults.User.hasIndexedSearchableItems = true
        queue.async {
            let searchableItems = UserDAO.shared.getAppUsers().compactMap {
                self.searchableItem(userId: $0.userId, name: $0.fullName, biography: $0.biography, avatarUrl: $0.avatarUrl)
            }
            CSSearchableIndex.default().indexSearchableItems(searchableItems)
        }
    }
    
    func contiune(_ activity: NSUserActivity) {
        guard
            let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
            let userId = identifier.components(separatedBy: ".").last,
            let user = UserDAO.shared.getUser(userId: userId)
        else {
            return
        }
        let presentUserProfileController = {
            let controller = UserProfileViewController.init(user: user)
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
    
    @objc private func cleanupSearchableItems() {
        queue.async {
            CSSearchableIndex.default().deleteAllSearchableItems()
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
            CSSearchableIndex.default().indexSearchableItems(needsIndexedItems)
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: needsDeletedItems)
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
        let domainIdentifier = "one.mixin.messenger.spotlight.apps"
        return CSSearchableItem(uniqueIdentifier: uniqueIdentifier, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
    }
    
    private func uniqueIdentifier(for userId: String) -> String {
        "one.mixin.messenger.spotlight.app.\(userId)"
    }
    
}
