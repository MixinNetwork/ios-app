import Foundation

struct BlazeMessage: Encodable {

    var id: String
    var action: String
    var params: BlazeMessageParam?
    let data: String?
    let error: APIError?

    var fromPush: Bool? = nil

    func isReceiveMessageAction() -> Bool {
        return action == BlazeMessageAction.createMessage.rawValue
            || action == BlazeMessageAction.createCall.rawValue
            || action == BlazeMessageAction.acknowledgeMessageReceipt.rawValue
    }
}

enum BlazeMessageAction: String {
    case createMessage = "CREATE_MESSAGE"
    case createSignalKeyMessage = "CREATE_SIGNAL_KEY_MESSAGES"
    case createCall = "CREATE_CALL"
    case acknowledgeMessageReceipt = "ACKNOWLEDGE_MESSAGE_RECEIPT"
    case acknowledgeMessageReceipts = "ACKNOWLEDGE_MESSAGE_RECEIPTS"
    case listPendingMessages = "LIST_PENDING_MESSAGES"
    case error = "ERROR"
    case countSignalKeys = "COUNT_SIGNAL_KEYS"
    case consumeSignalKeys = "CONSUME_SIGNAL_KEYS"
    case consumeSessionSignalKeys = "CONSUME_SESSION_SIGNAL_KEYS"
    case syncSignalKeys = "SYNC_SIGNAL_KEYS"
}

extension BlazeMessage {
    init(data: BlazeMessageData, action: String, fromPush: Bool? = nil) {
        self.id = UUID().uuidString.lowercased()
        self.action = action
        self.params = nil
        self.data = data.toJSON()
        self.error = nil
        self.fromPush = fromPush
    }

    init(params: BlazeMessageParam, action: String) {
        self.id = UUID().uuidString.lowercased()
        self.action = action
        self.params = params
        self.data = nil
        self.error = nil
    }

    init(action: String) {
        self.id = UUID().uuidString.lowercased()
        self.action = action
        self.params = nil
        self.data = nil
        self.error = nil
    }

    init(ackBlazeMessage messageId: String, status: String) {
        let params = BlazeMessageParam(messageId: messageId, status: status)
        self.init(params: params, action: BlazeMessageAction.acknowledgeMessageReceipt.rawValue)
    }

    init(recallMessageId messageId: String, conversationId: String) {
        let transferPlainData = TransferRecallData(messageId: messageId)
        let encoded = (try? JSONEncoder().encode(transferPlainData).base64EncodedString()) ?? ""
        let params = BlazeMessageParam(conversationId: conversationId, category: MessageCategory.MESSAGE_RECALL.rawValue, data: encoded, status: MessageStatus.SENDING.rawValue, messageId: messageId)
        self.init(params: params, action: BlazeMessageAction.createMessage.rawValue)
    }
}

extension BlazeMessage {

    func toBlazeMessageData() -> BlazeMessageData? {
        guard let data = self.data?.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(BlazeMessageData.self, from: data)
    }

    func toSignalKeyCount() -> SignalKeyCount? {
        guard let data = self.data?.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(SignalKeyCount.self, from: data)
    }

    func toConsumeSignalKeys() -> [SignalKey]? {
        guard let data = self.data?.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode([SignalKey].self, from: data)
    }

}

extension BlazeMessage: Decodable {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.getString(key: .id)
        action = container.getString(key: .action)

        switch action {
        case BlazeMessageAction.listPendingMessages.rawValue:
            data = nil
        case BlazeMessageAction.createMessage.rawValue, BlazeMessageAction.acknowledgeMessageReceipt.rawValue, BlazeMessageAction.createCall.rawValue:
            let messageData: BlazeMessageData? = container.getCodable(key: .data)
            data = messageData != nil ? String(data: try JSONEncoder().encode(messageData), encoding: .utf8) : nil
        case BlazeMessageAction.countSignalKeys.rawValue:
            let count: SignalKeyCount? = container.getCodable(key: .data)
            data = count != nil ? String(data: try JSONEncoder().encode(count), encoding: .utf8) : nil
        case BlazeMessageAction.consumeSignalKeys.rawValue, BlazeMessageAction.consumeSessionSignalKeys.rawValue:
            let keys: [SignalKey]? = container.getCodable(key: .data)
            data = keys != nil ? String(data: try JSONEncoder().encode(keys), encoding: .utf8) : nil
        default:
            data = nil
        }

        params = container.getCodable(key: .params)
        error = container.getCodable(key: .error)
    }

}
