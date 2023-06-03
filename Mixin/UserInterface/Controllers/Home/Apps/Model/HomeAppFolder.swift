import Foundation
import MixinServices

final class HomeAppFolder {
    
    var name: String
    var pages: [[HomeApp]]
    var isNewlyCreated = false
    
    init(name: String, pages: [[HomeApp]]) {
        self.name = name
        self.pages = pages
    }
    
}

extension HomeAppFolder: Equatable {
    
    static func == (lhs: HomeAppFolder, rhs: HomeAppFolder) -> Bool {
        return lhs === rhs
    }
    
}

extension HomeAppFolder: Codable {
    
    enum CodingKeys: CodingKey {
        case name
        case id
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let ids = try container.decode([[String]].self, forKey: .id)
        let userMap = UserDAO.shared.getFriendUsers(withAppIds: ids.flatMap({ $0 }))
            .reduce(into: [String: User]()) { result, user in
                if let appId = user.appId {
                    result[appId] = user
                }
            }
        let pages = ids.compactMap { pageIds -> [HomeApp]? in
            let apps = pageIds.compactMap { id -> HomeApp? in
                if let user = userMap[id] {
                    return .external(user)
                } else if let app = EmbeddedApp.all.first(where: { $0.id == id }) {
                    return .embedded(app)
                } else {
                    return nil
                }
            }
            return apps.isEmpty ? nil : apps
        }
        self.init(name: name, pages: pages)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(pages.map { $0.map(\.id) }, forKey: .id)
    }
    
}
