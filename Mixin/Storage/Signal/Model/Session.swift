import WCDBSwift

struct Session: BaseCodable {

    static var tableName: String = "sessions"

    var id: Int?
    let address: String
    let device: Int
    let record: Data
    let timestamp: TimeInterval

    init(address: String, device: Int, record: Data, timestamp: TimeInterval) {
        self.address = address
        self.device = device
        self.record = record
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = Session
        case id
        case address
        case device
        case record
        case timestamp

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                id: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true)
            ]
        }
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return  [
                "_multi_index": IndexBinding(isUnique: true, indexesBy: address, device)
            ]
        }
    }

    var isAutoIncrement: Bool {
        return true
    }
}
