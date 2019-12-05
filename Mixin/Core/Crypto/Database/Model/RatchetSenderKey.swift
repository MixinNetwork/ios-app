import WCDBSwift

struct RatchetSenderKey: BaseCodable {

    static var tableName: String = "ratchet_sender_keys"

    let groupId: String
    let senderId: String
    let status: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = RatchetSenderKey
        case groupId
        case senderId
        case status

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: groupId, senderId)
            ]
        }
    }

}

enum RatchetStatus: String {
    case REQUESTING
}
