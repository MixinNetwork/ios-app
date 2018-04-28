import WCDBSwift

struct Identity: BaseCodable {

    static var tableName: String = "identities"

    var id: Int?
    let address: String
    let registrationId: Int?
    let publicKey: Data
    let privateKey: Data?
    let nextPreKeyId: Int64?
    let timestamp: TimeInterval

    init(address: String, registrationId: Int?, publicKey: Data, privateKey: Data?, nextPreKeyId: Int64?, timestamp: TimeInterval) {
        self.address = address
        self.registrationId = registrationId
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.nextPreKeyId = nextPreKeyId
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = Identity
        case id
        case address
        case registrationId
        case publicKey
        case privateKey
        case nextPreKeyId
        case timestamp

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                id: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true)
            ]
        }
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_index_id": IndexBinding(isUnique: true, indexesBy: address)
            ]
        }
    }

    var isAutoIncrement: Bool {
        return true
    }
}

extension Identity {
    func getIdentityKeyPair() -> KeyPair {
        return KeyPair(publicKey: publicKey, privateKey: privateKey!)
    }
}
