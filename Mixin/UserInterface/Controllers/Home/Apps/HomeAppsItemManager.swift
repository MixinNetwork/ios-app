import Foundation
import MixinServices

class HomeAppsItemManager {
    
    typealias JSONDictionary = [String: Any]
    typealias JSONArray = [JSONDictionary]
    
    private(set) var candidateItems: [[AppItem]] = []
    private(set) var pinnedItems: [AppItem] = []
    private var existsItemIds: Set<String> = []
    
    func loadData(completion: @escaping (_ pinnedItems: [AppItem], _ candidateItems: [[AppItem]]) -> Void) {
        DispatchQueue.global().async {
            if let jsonData = AppGroupUserDefaults.User.homeAppsFolder {
                self.setupItems(with: jsonData)
            } else {
                self.initItems()
                self.saveItems()
            }
            DispatchQueue.main.sync {
                completion(self.pinnedItems, self.candidateItems)
            }
        }
    }
    
    func updateItems(_ pinnedItems: [AppItem], _ candidateItems: [[AppItem]]) {
        self.pinnedItems = pinnedItems
        self.candidateItems = candidateItems
        saveItems()
    }
    
}

extension HomeAppsItemManager {
    
    private func initItems() {
        var pinnedIds = Set(AppGroupUserDefaults.User.homeAppIds)
        if pinnedIds.count > HomeAppsMode.pinned.appsPerRow {
            pinnedIds = Set(pinnedIds.prefix(HomeAppsMode.pinned.appsPerRow))
        }
        pinnedItems = pinnedIds.compactMap({ id -> AppModel? in
            guard let app = HomeApp(id: id) else { return nil }
            return AppModel(id: id, app: app)
        })
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
            let items = candidateEmbeddedApps.map({ AppModel(id: $0.id, app: .embedded($0)) })
                + candidateAppUsers.map({ AppModel(id: $0.appId!, app: .external($0)) })
            return items.splitInPages(ofSize: HomeAppsMode.regular.appsPerPage)
        }()
    }
    
    private func setupItems(with jsonData: Data) {
        existsItemIds.removeAll()
        let embeddedApps = EmbeddedApp.all
        let appUsers = UserDAO.shared.getAppUsers()
        let embeddedAppIds = embeddedApps.map({ $0.id })
        let appUserIds = appUsers.compactMap({ $0.appId })
        let allAppIds = embeddedAppIds + appUserIds
        do {
            if let parsedDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? JSONDictionary,
               let pinnedJSONArray = parsedDict["pinned"] as? JSONArray,
               let pagesJSONArray = parsedDict["pages"] as? [JSONArray] {
                pinnedItems = pinnedAppItems(from: pinnedJSONArray, allAppIds: allAppIds)
                candidateItems = pagesJSONArray.compactMap({ jsonArray -> [AppItem]? in
                    let page = candidateAppItems(from: jsonArray, allAppIds: allAppIds, embeddedApps: embeddedApps, appUsers: appUsers)
                    return page.count > 0 ? page : nil
                })
                // apped newly added apps
                let newlyAddedItemIds = Set(allAppIds).subtracting(existsItemIds)
                if newlyAddedItemIds.count > 0 {
                    let newlyAddedItems = newlyAddedItemIds.compactMap { id -> AppModel? in
                        guard let app = HomeApp(id: id) else { return nil }
                        return AppModel(id: id, app: app)
                    }
                    let newlyAddedItemPages = newlyAddedItems.splitInPages(ofSize: HomeAppsMode.regular.appsPerPage)
                    candidateItems += newlyAddedItemPages
                }
            } else {
                initItems()
            }
        } catch {
            initItems()
        }
    }
    
    private func pinnedAppItems(from jsonArray: JSONArray, allAppIds: [String]) -> [AppItem] {
        return jsonArray.compactMap { item -> AppItem? in
            guard let typeID = item["type"] as? Int, let type = HomeAppItemType(rawValue: typeID), type == .app else {
                return nil
            }
            guard let id = item["id"] as? String, allAppIds.contains(id), !existsItemIds.contains(id) else {
                return nil
            }
            existsItemIds.insert(id)
            return AppModel(id: id, app: HomeApp(id: id)!)
        }
    }
    
    private func candidateAppItems(from jsonArray: JSONArray, allAppIds: [String], embeddedApps: [EmbeddedApp], appUsers: [User]) -> [AppItem] {
        let pinnedIds = pinnedItems.compactMap({ ($0 as? AppModel)?.id })
        var candidateEmbeddedApps = embeddedApps
        candidateEmbeddedApps.removeAll(where: {
            pinnedIds.contains($0.id)
        })
        let candidateAppUsers = appUsers.filter { (user) -> Bool in
            if let id = user.appId {
                return !pinnedIds.contains(id)
            } else {
                return false
            }
        }
        return jsonArray.compactMap { item -> AppItem? in
            guard let typeID = item["type"] as? Int, let type = HomeAppItemType(rawValue: typeID) else {
                return nil
            }
            switch type {
            case .app:
                guard let id = item["id"] as? String, allAppIds.contains(id), !existsItemIds.contains(id) else {
                    return nil
                }
                existsItemIds.insert(id)
                if let embeddedApp = candidateEmbeddedApps.first(where: { $0.id == id }) {
                    return AppModel(id: id, app: .embedded(embeddedApp))
                } else if let appUser = candidateAppUsers.first(where: { $0.appId == id }) {
                    return AppModel(id: id, app: .external(appUser))
                } else {
                    return nil
                }
            case .folder:
                guard let name = item["name"] as? String, let apps = item["apps"] as? [[JSONDictionary]] else {
                    return nil
                }
                let pages = apps.compactMap { pageItems -> [AppModel]? in
                    let page = pageItems.compactMap { item -> AppModel? in
                        guard let id = item["id"] as? String, allAppIds.contains(id), !existsItemIds.contains(id) else {
                            return nil
                        }
                        existsItemIds.insert(id)
                        if let embeddedApp = candidateEmbeddedApps.first(where: { $0.id == id }) {
                            return AppModel(id: id, app: .embedded(embeddedApp))
                        } else if let appUser = candidateAppUsers.first(where: { $0.appId == id }) {
                            return AppModel(id: id, app: .external(appUser))
                        } else {
                            return nil
                        }
                    }
                    return page.count > 0 ? page : nil
                }
                return pages.count > 0 ? AppFolderModel(name: name, pages: pages) : nil
            }
        }
    }
    
    private func saveItems() {
        DispatchQueue.global().async {
            let pinnedItems = self.pinnedItems.map { $0.toDictionary() }
            let pages = self.candidateItems.map { page -> [JSONDictionary] in
                return page.map { $0.toDictionary() }
            }
            let dictionary = ["pages": pages, "pinned": pinnedItems] as JSONDictionary
            let jsonData = try! JSONSerialization.data(withJSONObject: dictionary, options: [])
            AppGroupUserDefaults.User.homeAppsFolder = jsonData
            AppGroupUserDefaults.User.homeAppIds = self.pinnedItems.compactMap({ ($0 as? AppModel)?.id })
        }
    }
    
}
