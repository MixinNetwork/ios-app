import Foundation
import WCDBSwift

struct ConversationCategoryStorage: TableCodable {

    let category: String
    let mediaSize: Int64

    enum CodingKeys: String, CodingTableKey {
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        typealias Root = ConversationCategoryStorage

        case category
        case mediaSize
    }

}
