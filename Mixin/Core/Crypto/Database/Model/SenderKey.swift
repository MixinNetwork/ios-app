import WCDBSwift

struct SenderKey: BaseCodable {

    static var tableName: String = "sender_keys"

    let groupId: String
    let senderId: String
    let record: Data

    enum CodingKeys: String, CodingTableKey {
        typealias Root = SenderKey
        case groupId
        case senderId
        case record

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: groupId, senderId)
            ]
        }
    }
}
