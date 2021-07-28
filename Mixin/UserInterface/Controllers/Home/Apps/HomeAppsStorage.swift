import Foundation
import MixinServices

class HomeAppsStorage {
    
    private enum Error: Swift.Error {
        case missingApps
    }
    
    private static let usersKey = CodingUserInfoKey(rawValue: "users")!
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.HomeAppsStorage")
    
    func load(completion: @escaping (_ pinnedItems: [HomeApp], _ candidateItems: [[HomeAppItem]]) -> Void) {
        queue.async {
            let pinned = AppGroupUserDefaults.User.homeAppIds
                .prefix(HomeAppsMode.pinned.appsPerRow)
                .compactMap(HomeApp.init(id:))
            let candidate: [[HomeAppItem]]
            let decoder = JSONDecoder()
            decoder.userInfo = [HomeAppsStorage.usersKey: UserDAO.shared.getAppUsers()]
            if let json = AppGroupUserDefaults.User.homeAppsFolder,
               let wrappers = try? decoder.decode([HomeAppItemsWrapper].self, from: json) {
                var items = self.candidateItems(with: wrappers)
                var existedIds = Set(pinned.map(\.id))
                for item in items.flatMap({ $0 }) {
                    switch item {
                    case let .app(app):
                        existedIds.insert(app.id)
                    case let .folder(folder):
                        let ids = folder.pages.flatMap { $0 }.map(\.id)
                        existedIds.formUnion(ids)
                    }
                }
                let newApps = UserDAO.shared.getAppUsersAppId()
                    .filter { !existedIds.contains($0) }
                    .compactMap { HomeApp(id: $0) }
                if !newApps.isEmpty {
                    if let lastPage = items.last, lastPage.count < HomeAppsMode.regular.appsPerPage {
                        let trailingApps: [HomeAppItem] = newApps
                            .prefix(HomeAppsMode.regular.appsPerPage - lastPage.count)
                            .map { .app($0) }
                        items[items.count - 1].append(contentsOf: trailingApps)
                        if newApps.count > trailingApps.count {
                            let newPages: [[HomeAppItem]] = newApps
                                .suffix(newApps.count - trailingApps.count)
                                .map { .app($0) }
                                .slices(ofSize: HomeAppsMode.regular.appsPerPage)
                            items.append(contentsOf: newPages)
                        }
                    } else {
                        let newPages: [[HomeAppItem]] = newApps
                            .map { .app($0) }
                            .slices(ofSize: HomeAppsMode.regular.appsPerPage)
                        items.append(contentsOf: newPages)
                    }
                    self.save(candidateItems: items)
                }
                candidate = items
            } else {
                let pinnedIds = Set(pinned.map(\.id))
                candidate = self.defaultCandidateItems(with: pinnedIds)
                self.save(candidateItems: candidate)
            }
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
    
    private func defaultCandidateItems(with pinnedIds: Set<String>) -> [[HomeAppItem]] {
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
        return allCandidates.slices(ofSize: HomeAppsMode.regular.appsPerPage)
    }
    
    private func candidateItems(with wrappers: [HomeAppItemsWrapper]) -> [[HomeAppItem]] {
        var needsSave = false
        let candidateItems = wrappers.compactMap { wrapper -> [HomeAppItem]? in
            guard !wrapper.items.isEmpty else {
                needsSave = true
                return nil
            }
            var items = wrapper.items
            if items.count > HomeAppsMode.regular.appsPerPage {
                needsSave = true
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
                let apps: [HomeApp] = removedItems.reduce([]) { previous, item in
                    switch item {
                    case .app(let app):
                        return previous + [app]
                    case .folder(let folder):
                        return previous + folder.pages.flatMap { $0 }
                    }
                }
                let pages: [[HomeApp]]
                if let folder = appFolder {
                    pages = folder.pages + apps.slices(ofSize: HomeAppsMode.folder.appsPerPage)
                } else {
                    pages = apps.slices(ofSize: HomeAppsMode.folder.appsPerPage)
                }
                items.removeLast(items.count - HomeAppsMode.regular.appsPerPage + 1)
                let folder = HomeAppFolder(name: folderName, pages: pages)
                items.append(.folder(folder))
            }
            return items
        }
        if needsSave {
            save(candidateItems: candidateItems)
        }
        return candidateItems
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
            guard let users = decoder.userInfo[HomeAppsStorage.usersKey] as? [User] else {
                throw Error.missingApps
            }
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
                    if let app = EmbeddedApp.all.first(where: { $0.id == id }) {
                        items.append(.app(.embedded(app)))
                    } else if let user = users.first(where: { $0.appId == id }) {
                        items.append(.app(.external(user)))
                    } else {
                        continue
                    }
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
