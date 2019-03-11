import Foundation
import WCDBSwift

struct UserSession: BaseCodable {

    static var tableName: String = "sessions"

    let sessionId: String
    let userId: String
    let deviceId: Int

    enum CodingKeys: String, CodingTableKey {
        typealias Root = UserSession
        case sessionId = "session_id"
        case userId = "user_id"
        case deviceId = "device_id"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                sessionId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
}
