import Foundation
import MixinServices

class HomeFolderModel: HomeItemModel {
    
    var id: String
    var name: String
    var apps: [HomeApp]
    
    init(id: String, name: String, apps: [HomeApp]) {
        self.id = id
        self.name = name
        self.apps = apps
    }
    
}
