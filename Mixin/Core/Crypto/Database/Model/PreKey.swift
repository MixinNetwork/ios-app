import WCDBSwift

struct PreKey: BaseCodable {

    static var tableName: String = "prekeys"

    var id: Int?
    let preKeyId: Int
    let record: Data

    init(preKeyId: Int, record: Data) {
        self.preKeyId = preKeyId
        self.record = record
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = PreKey
        case id
        case preKeyId
        case record

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
