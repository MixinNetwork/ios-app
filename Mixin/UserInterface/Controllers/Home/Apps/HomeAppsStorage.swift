import Foundation
import MixinServices

class HomeAppsStorage {
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.HomeAppsItemManager")
    
    func load(completion: @escaping (_ pinnedItems: [HomeApp], _ candidateItems: [[HomeAppItem]]) -> Void) {
        queue.async {
            let (pinned, candidate) = { () -> ([HomeApp], [[HomeAppItem]]) in
                let pinned = AppGroupUserDefaults.User.homeAppIds
                    .prefix(HomeAppsMode.pinned.appsPerRow)
                    .compactMap(HomeApp.init(id:))
                if let json = AppGroupUserDefaults.User.homeAppsFolder, let items = try? JSONDecoder.default.decode([HomeAppItemsWrapper].self, from: json) {
                    var needsSave = false
                    let candidateItems = items.map { homeAppItemsWrapper -> [HomeAppItem] in
                        var items = homeAppItemsWrapper.items
                        if items.count > HomeAppsMode.regular.appsPerPage {
                            needsSave = true
                            let apps: [HomeApp]
                            let pages: [[HomeApp]]
                            let folderName: String
                            var appFolder: HomeAppFolder?
                            var removedItems = items.suffix(items.count - HomeAppsMode.regular.appsPerPage + 1)
                            switch removedItems.first! {
                            case .app(let app):
                                folderName = app.category
                            case .folder(let folder):
                                folderName = folder.name
                                appFolder = folder
                                removedItems.removeFirst()
                            }
                            apps = removedItems.reduce([HomeApp]()) { result, homeAppItem in
                                switch homeAppItem {
                                case .app(let app):
                                    return result + [app]
                                case .folder(let folder):
                                    return result + folder.pages.flatMap({ $0 })
                                }
                            }
                            if let folder = appFolder {
                                pages = folder.pages + apps.splitInPages(ofSize: HomeAppsMode.folder.appsPerPage)
                            } else {
                                pages = apps.splitInPages(ofSize: HomeAppsMode.folder.appsPerPage)
                            }
                            items.removeLast(items.count - HomeAppsMode.regular.appsPerPage + 1)
                            items.append(HomeAppItem(folder: HomeAppFolder(name: folderName, pages: pages)))
                        }
                        return items
                    }
                    if needsSave {
                        self.save(candidateItems: candidateItems)
                    }
                    return (pinned, candidateItems)
                } else {
                    let candidateItems: [[HomeAppItem]] = {
                        let pinnedIds = Set(pinned.map(\.id))
                        let candidateEmbeddedApps = EmbeddedApp.all.filter { !pinnedIds.contains($0.id) }
                        let appUsers = UserDAO.shared.getAppUsers().filter { (user) -> Bool in
                            if let id = user.appId {
                                return !pinnedIds.contains(id)
                            } else {
                                return false
                            }
                        }
                        let allCandidates = candidateEmbeddedApps.map { HomeAppItem.app(.embedded($0)) }
                            + appUsers.map { HomeAppItem.app(.external($0)) }
                        return allCandidates.splitInPages(ofSize: HomeAppsMode.regular.appsPerPage)
                    }()
                    self.save(candidateItems: candidateItems)
                    return (pinned, candidateItems)
                }
            }()
            DispatchQueue.main.sync {
                completion(pinned, candidate)
            }
        }
    }
    
    func save(pinnedApps: [HomeApp]) {
        queue.async {
            AppGroupUserDefaults.User.homeAppIds = pinnedApps.map(\.id)
        }
    }
    
    func save(candidateItems: [[HomeAppItem]]) {
        queue.async {
            let candidateWrappers = candidateItems.map(HomeAppItemsWrapper.init(items:))
            AppGroupUserDefaults.User.homeAppsFolder = try? JSONEncoder.default.encode(candidateWrappers)
        }
    }
    
}

extension HomeAppsStorage {
    
    private struct HomeAppItemsWrapper: Codable {
        
        enum ItemType: String, Codable {
            case app, folder
        }
        
        enum CodingKeys: CodingKey {
            case type, value
        }
        
        let items: [HomeAppItem]
        
        init(items: [HomeAppItem]) {
            self.items = items
        }
        
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var items: [HomeAppItem] = []
            while !container.isAtEnd {
                let nestedContainer = try container.nestedContainer(keyedBy: CodingKeys.self)
                guard let type = try? nestedContainer.decode(ItemType.self, forKey: .type) else {
                    continue
                }
                switch type {
                case .app:
                    guard let id = try? nestedContainer.decode(String.self, forKey: .value) else {
                        continue
                    }
                    guard let app = HomeApp(id: id) else {
                        continue
                    }
                    items.append(.app(app))
                case .folder:
                    guard let folder = try? nestedContainer.decode(HomeAppFolder.self, forKey: .value) else {
                        continue
                    }
                    items.append(.folder(folder))
                }
            }
            self.items = items
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            for item in items {
                switch item {
                case .app(let app):
                    var nestedContainer = container.nestedContainer(keyedBy: CodingKeys.self)
                    try nestedContainer.encode(ItemType.app, forKey: .type)
                    try nestedContainer.encode(app.id, forKey: .value)
                case .folder(let folder):
                    var nestedContainer = container.nestedContainer(keyedBy: CodingKeys.self)
                    try nestedContainer.encode(ItemType.folder, forKey: .type)
                    try nestedContainer.encode(folder, forKey: .value)
                }
            }
        }
        
    }
    
}
