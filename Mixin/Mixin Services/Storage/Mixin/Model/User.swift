import Foundation
import WCDBSwift

public struct User: BaseCodable {
    
    static var tableName: String = "users"
    
    let userId: String
    let fullName: String?
    let biography: String?
    let identityNumber: String
    let avatarUrl: String?
    var phone: String? = nil
    var isVerified: Bool? = nil
    var muteUntil: String? = nil
    var appId: String? = nil
    let createdAt: String?
    let relationship: String
    
    var app: App? = nil
    
    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = User
        case userId = "user_id"
        case fullName = "full_name"
        case biography = "biography"
        case identityNumber = "identity_number"
        case avatarUrl = "avatar_url"
        case phone
        case isVerified = "is_verified"
        case muteUntil = "mute_until"
        case appId = "app_id"
        case relationship
        case createdAt = "created_at"
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                userId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
    
    static let systemUser = "00000000-0000-0000-0000-000000000000"
    
    static func createSystemUser() -> User {
        return User(userId: systemUser, fullName: "0", biography: "", identityNumber: "0", avatarUrl: nil, phone: nil, isVerified: false, muteUntil: nil, appId: nil, createdAt: nil, relationship: "", app: nil)
    }
    
    static func createUser(from user: UserResponse) -> User {
        return User(userId: user.userId, fullName: user.fullName, biography: user.biography, identityNumber: user.identityNumber, avatarUrl: user.avatarUrl, phone: user.phone, isVerified: user.isVerified, muteUntil: user.muteUntil, appId: user.app?.appId, createdAt: user.createdAt, relationship: user.relationship.rawValue, app: user.app)
    }
    
    static func createUser(from account: Account) -> User {
        return User(userId: account.user_id, fullName: account.full_name, biography: account.biography, identityNumber: account.identity_number, avatarUrl: account.avatar_url, phone: account.phone, isVerified: false, muteUntil: nil, appId: nil, createdAt: account.created_at, relationship: Relationship.ME.rawValue, app: nil)
    }
    
}
