import Foundation
import WCDBSwift

public struct ConversationCategoryStorage: TableCodable {

    let category: String
    let mediaSize: Int64
    let messageCount: Int

    public enum CodingKeys: String, CodingTableKey {
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public typealias Root = ConversationCategoryStorage

        case category
        case mediaSize
        case messageCount
    }

}
