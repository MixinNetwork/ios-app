import WCDBSwift

public struct FavoriteApp: BaseCodable {
    
    public static let tableName: String = "favorite_apps"
    
    public let userId: String
    public let appId: String
    public let createdAt: String
    
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
