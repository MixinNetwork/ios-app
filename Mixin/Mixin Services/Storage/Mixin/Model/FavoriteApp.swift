import WCDBSwift

public struct FavoriteApp: BaseCodable {
    
    static let tableName: String = "favorite_apps"
    
    let userId: String
    let appId: String
    let createdAt: String
    
}

extension FavoriteApp {
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = FavoriteApp
        
        case userId = "user_id"
        case appId = "app_id"
        case createdAt = "created_at"
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        public static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: userId, appId)
            ]
        }
        
    }
    
}
