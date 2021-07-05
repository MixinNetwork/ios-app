import Foundation
import MixinServices

class HomeAppsItemManager {
    
    typealias JSONDictionary = [String: Any]
    typealias JSONArray = [JSONDictionary]
    
    var candidateItems: [[BotItem]] = []
    var pinnedItems: [BotItem] = []
    
    init() {
        if let jsonData = AppGroupUserDefaults.User.homeAppsFolder {
            let parsedDict = (try! JSONSerialization.jsonObject(with: jsonData, options: [])) as! JSONDictionary
            candidateItems = (parsedDict["pages"] as! [JSONArray]).map { appItems(from: $0) }
            pinnedItems = appItems(from: parsedDict["pinned"] as! JSONArray)
            synchronizeItems()
        } else {
            initItems()
            save()
        }
    }
    
    func save() {
        DispatchQueue.global(qos: .utility).async {
            let pinnedItems = self.pinnedItems.map { $0.toDictionary() }
            let pages = self.candidateItems.map { page -> [JSONDictionary] in
                return page.map { $0.toDictionary() }
            }
            let dictionary = ["pages": pages, "pinned": pinnedItems] as JSONDictionary
            let jsonData = try! JSONSerialization.data(withJSONObject: dictionary, options: [])
            AppGroupUserDefaults.User.homeAppsFolder = jsonData
        }
    }
    
}

extension HomeAppsItemManager {
    
    private func initItems() {
        let pinnedIds = AppGroupUserDefaults.User.homeAppIds
        pinnedItems = pinnedIds.compactMap({ return Bot(id: $0) })
        
        var candidateEmbeddedApps = EmbeddedApp.all
        candidateEmbeddedApps.removeAll(where: {
            pinnedIds.contains($0.id)
        })
        let appUsers = UserDAO.shared.getAppUsers()
        let candidateAppUsers = appUsers.filter { (user) -> Bool in
            if let id = user.appId {
                return !pinnedIds.contains(id)
            } else {
                return false
            }
        }
        candidateItems = {
            let itemIds = candidateEmbeddedApps.map({ $0.id }) + candidateAppUsers.compactMap({ $0.appId })
            let items = itemIds.map({ Bot(id: $0) })
            let size = HomeAppsMode.regular.appsPerPage
            let count = items.count
            return stride(from: 0, to: count, by: size).map({
                Array(items[$0..<min($0+size, count)])
            })
        }()
    }
    
    private func appItems(from jsonArray: JSONArray) -> [BotItem] {
        return jsonArray.compactMap { item -> BotItem? in
            guard let typeID = item["type"] as? Int, let type = HomeAppItemType(rawValue: typeID) else {
                return nil
            }
            switch type {
            case .app:
                guard let id = item["id"] as? String else {
                    return nil
                }
                return Bot(id: id)
            case .folder:
                guard let name = item["name"] as? String, let apps = item["apps"] as? [[JSONDictionary]] else {
                    return nil
                }
                let pages = apps.map { itemArray in
                    return itemArray.compactMap { item -> Bot? in
                        guard let id = item["id"] as? String else {
                            return nil
                        }
                        return Bot(id: id)
                    }
                }
                return BotFolder(name: name, pages: pages)
            }
        }
    }
    
    private func synchronizeItems() {
        
    }
    
}

