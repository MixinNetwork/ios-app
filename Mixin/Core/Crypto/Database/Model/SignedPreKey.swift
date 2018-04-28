import WCDBSwift

struct SignedPreKey: BaseCodable {

    static var tableName: String = "signed_prekeys"

    var id: Int?
    let preKeyId: Int
    let record: Data
    let timestamp: TimeInterval

    init(preKeyId: Int, record: Data, timestamp: TimeInterval) {
        self.preKeyId = preKeyId
        self.record = record
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = SignedPreKey
        case id
        case preKeyId
        case record
        case timestamp

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                id: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true)
            ]
        }
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_index_id": IndexBinding(isUnique: true, indexesBy: preKeyId)
            ]
        }
    }

    var isAutoIncrement: Bool {
        return true
    }
}
