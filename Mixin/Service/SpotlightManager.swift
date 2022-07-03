import Foundation
import CoreSpotlight
import MobileCoreServices
import MixinServices

class SpotlightManager: NSObject {
    
    private enum State {
        static let none = Data([0x00])
        static let finished = Data([0x01])
    }
    
    static let shared = SpotlightManager()
    
    static var isAvailable: Bool {
        CSSearchableIndex.isIndexingAvailable()
    }
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.spotlight")
    private let index = CSSearchableIndex(name: "one.mixin.messenger")
    
    override init() {
        super.init()
        index.indexDelegate = self
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(deleteAllIndexedItems), name: LoginManager.didLogoutNotification, object: nil)
        center.addObserver(self, selector: #selector(updateSearchableItems), name: UserDAO.usersDidChangeNotification, object: nil)
    }
    
    func canContinue(activity: NSUserActivity) -> Bool {
        activity.activityType == CSSearchableItemActionType
    }
    
    func contiune(activity: NSUserActivity) {
        guard
            let userId = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
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
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        queue.async {
            self.index.fetchLastClientState { data, error in
                if let error = error {
                    Logger.general.error(category: "SpotlightManager", message: "Failed to fetch client state: \(error)")
                } else if data != State.finished {
                    self.reindexAllSearchableItems()
                }
            }
        }
    }
    
    @objc func deleteAllIndexedItems() {
        queue.async {
            self.index.beginBatch()
            self.index.deleteAllSearchableItems()
            self.index.endBatch(withClientState: State.none) { error in
                if let error = error {
                    Logger.general.error(category: "SpotlightManager", message: "Failed to delete all items, error: \(error)")
                } else {
                    Logger.general.info(category: "SpotlightManager", message: "Deleted all items")
                }
            }
        }
    }
    
    @objc private func updateSearchableItems(_ notification: Notification) {
        guard let userResponses = notification.userInfo?[UserDAO.UserInfoKey.users] as? [UserResponse] else {
            return
        }
        queue.async {
            var unwantedUserIds: [String] = []
            var newItems: [CSSearchableItem] = []
            for response in userResponses where response.app != nil {
                if response.relationship == .FRIEND {
                    let user = User.createUser(from: response)
                    if let item = self.searchableItem(user: user) {
                        newItems.append(item)
                    }
                } else {
                    unwantedUserIds.append(response.userId)
                }
            }
            if !unwantedUserIds.isEmpty || !newItems.isEmpty {
                self.index.beginBatch()
                self.index.indexSearchableItems(newItems)
                self.index.deleteSearchableItems(withIdentifiers: unwantedUserIds)
                self.index.endBatch(withClientState: State.finished) { error in
                    if let error = error {
                        Logger.general.error(category: "SpotlightManager", message: "Failed to index \(newItems.count) items, delete \(unwantedUserIds.count) items, error: \(error)")
                    } else {
                        Logger.general.info(category: "SpotlightManager", message: "Indexed \(newItems.count) items, deleted \(unwantedUserIds.count) items")
                    }
                }
            }
        }
    }
    
}

extension SpotlightManager: CSSearchableIndexDelegate {
    
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        reindexAllSearchableItems()
        acknowledgementHandler()
    }
    
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        queue.async {
            let users = UserDAO.shared.getSearchableAppUsers(with: identifiers)
            let items = users.compactMap(self.searchableItem(user:))
            self.index.beginBatch()
            self.index.indexSearchableItems(items)
            self.index.endBatch(withClientState: State.finished) { error in
                if let error = error {
                    Logger.general.error(category: "SpotlightManager", message: "Failed to reindex with identifiers: \(error)")
                } else {
                    Logger.general.info(category: "SpotlightManager", message: "Indexed \(items.count) items")
                }
            }
        }
        acknowledgementHandler()
    }
    
}

extension SpotlightManager {
    
    private func reindexAllSearchableItems() {
        queue.async {
            let users = UserDAO.shared.getSearchableAppUsers(priorAppIds: AppGroupUserDefaults.User.recentlyUsedAppIds)
            let items = users.compactMap(self.searchableItem(user:))
            self.index.beginBatch()
            self.index.deleteAllSearchableItems()
            self.index.indexSearchableItems(items)
            self.index.endBatch(withClientState: State.finished) { error in
                if let error = error {
                    Logger.general.error(category: "SpotlightManager", message: "Failed to reindex: \(error)")
                } else {
                    Logger.general.info(category: "SpotlightManager", message: "Indexed \(items.count) items")
                }
            }
        }
    }
    
    private func searchableItem(user: User) -> CSSearchableItem? {
        guard let name = user.fullName else {
            return nil
        }
        let attributes: CSSearchableItemAttributeSet
        if #available(iOS 14.0, *) {
            attributes = CSSearchableItemAttributeSet(contentType: .text)
        } else {
            attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        }
        attributes.title = name
        attributes.keywords = [name]
        if let biography = user.biography {
            attributes.contentDescription = biography
        }
        if let avatarUrl = user.avatarUrl {
            attributes.thumbnailURL = URL(string: avatarUrl)
        }
        return CSSearchableItem(uniqueIdentifier: user.userId, domainIdentifier: "app", attributeSet: attributes)
    }
    
}
