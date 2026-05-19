import Foundation
import GRDB

struct PerpetualPositionUniqueIdentifier: Decodable, Equatable, Hashable, DatabaseColumnConvertible, MixinFetchableRecord {
    
    enum CodingKeys: String, CodingKey {
        case positionID = "position_id"
        case openPayAmount = "open_pay_amount"
    }
    
    let positionID: String
    let openPayAmount: String
    
    init(position: PerpetualPosition) {
        self.positionID = position.positionID
        self.openPayAmount = position.openPayAmount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(positionID)
        hasher.combine(openPayAmount)
    }
    
}

extension PerpetualPositionUniqueIdentifier: TableRecord {
    
    static let databaseTableName = "positions"
    
}
