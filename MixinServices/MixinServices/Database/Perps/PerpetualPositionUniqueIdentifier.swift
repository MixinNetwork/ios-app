import Foundation
import GRDB

struct PerpetualPositionUniqueIdentifier: Decodable, Equatable, Hashable, DatabaseColumnConvertible, MixinFetchableRecord {
    
    enum CodingKeys: String, CodingKey {
        case positionID = "position_id"
        case openPayAmount = "open_pay_amount"
        case margin = "margin"
    }
    
    let positionID: String
    let openPayAmount: String
    let margin: String
    
    init(position: PerpetualPosition) {
        self.positionID = position.positionID
        self.openPayAmount = position.openPayAmount
        self.margin = position.margin
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(positionID)
        hasher.combine(openPayAmount)
        hasher.combine(margin)
    }
    
}

extension PerpetualPositionUniqueIdentifier: TableRecord {
    
    static let databaseTableName = "positions"
    
}
