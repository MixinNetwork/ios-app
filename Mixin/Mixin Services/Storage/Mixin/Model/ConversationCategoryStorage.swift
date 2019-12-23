import Foundation
import WCDBSwift

public struct ConversationCategoryStorage: TableCodable {

    public let category: String
    public let mediaSize: Int64
    public let messageCount: Int

    public enum CodingKeys: String, CodingTableKey {
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public typealias Root = ConversationCategoryStorage

        case category
        case mediaSize
        case messageCount
    }

}
