import WCDBSwift

struct MessageFTS: BaseCodable {

    static var tableName: String = "fts_messages"

    var messageId: String
    var conversationId: String
    var content: String
    var name: String


    enum CodingKeys: String, CodingTableKey {
        typealias Root = MessageFTS
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case content
        case name

        static var virtualTableBinding: VirtualTableBinding? {
            return VirtualTableBinding(with: .fts3, and: ModuleArgument(with: .WCDB))
        }
    }
}
