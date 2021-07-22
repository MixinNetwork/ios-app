import Foundation

class HomeAppFolder: AppItem {
    
    var name: String
    var pages: [[AppModel]]
    var isNewFolder = false
    
    init(name: String, pages: [[AppModel]]) {
        self.name = name
        self.pages = pages
    }
    
    func toDictionary() -> [String : Any] {
        let apps = pages.map { page -> [[String : Any]] in
            return page.map { $0.toDictionary() }
        }
        return ["type": HomeAppItemType.folder.rawValue, "name": name, "apps": apps]
    }
    
}

extension HomeAppFolder: Equatable {
    
    static func == (lhs: HomeAppFolder, rhs: HomeAppFolder) -> Bool {
        return lhs === rhs
    }
    
}
