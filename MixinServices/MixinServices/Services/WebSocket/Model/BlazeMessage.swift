import Foundation

struct BlazeMessage {
    
    var id: String
    var action: String
    var params: BlazeMessageParam?
    let data: String?
    let error: MixinAPIError?
    
    var fromPush: Bool? = nil
    
    func isReceiveMessageAction() -> Bool {
        let actions: [BlazeMessageAction] = [
            .createMessage,
            .createCall,
            .createKraken,
            .acknowledgeMessageReceipt
        ]
        return actions.map(\.rawValue).contains(action)
    }
    
}

extension BlazeMessage: Encodable {
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(action, forKey: .action)
        try container.encode(params, forKey: .params)
        try container.encode(data, forKey: .data)
        // ⚠️ This func doesn't encode error since this is only used for message sending
    }
    
}

public enum BlazeMessageAction: String {
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
    case listKrakenPeers = "LIST_KRAKEN_PEERS"
    case createKraken = "CREATE_KRAKEN"
}

extension BlazeMessage: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        "<BlazeMessage id: \(id), action: \(action)>\n"
            + "data: \(data ?? "(null)")\n"
            + "param: \(params?.krakenDebugDescription ?? "(null)")\n"
    }
    
}

extension BlazeMessage {
    
    init(data: BlazeMessageData, action: String, fromPush: Bool? = nil) {
        self.id = UUID().uuidString.lowercased()
        self.action = action
        self.params = nil
        self.data = data.jsonRepresentation
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
        let encoded = (try? JSONEncoder.default.encode(transferPlainData).base64EncodedString()) ?? ""
        let params = BlazeMessageParam(conversationId: conversationId, category: MessageCategory.MESSAGE_RECALL.rawValue, data: encoded, status: MessageStatus.SENDING.rawValue, messageId: messageId)
        self.init(params: params, action: BlazeMessageAction.createMessage.rawValue)
    }
    
}

extension BlazeMessage {
    
    func toBlazeMessageData() -> BlazeMessageData? {
        guard let data = self.data?.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder.default.decode(BlazeMessageData.self, from: data)
    }
    
    func toSignalKeyCount() -> SignalKeyCount? {
        guard let data = self.data?.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder.default.decode(SignalKeyCount.self, from: data)
    }
    
    func toConsumeSignalKeys() -> [SignalKey]? {
        guard let data = self.data?.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder.default.decode([SignalKey].self, from: data)
    }
    
    func toKrakenPeers() -> [KrakenPeer]? {
        guard let data = self.data?.data(using: .utf8) else {
            return nil
        }
        do {
            return try JSONDecoder.default.decode([KrakenPeer].self, from: data)
        } catch {
            return nil
        }
    }
    
}

extension BlazeMessage: Decodable {
    
    enum CodingKeys: CodingKey {
        case id
        case action
        case params
        case data
        case error
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        action = try container.decodeIfPresent(String.self, forKey: .action) ?? ""
        
        switch action {
        case BlazeMessageAction.listPendingMessages.rawValue:
            data = nil
        case BlazeMessageAction.createMessage.rawValue, BlazeMessageAction.acknowledgeMessageReceipt.rawValue, BlazeMessageAction.createCall.rawValue, BlazeMessageAction.createKraken.rawValue:
            let messageData = try container.decodeIfPresent(BlazeMessageData.self, forKey: .data)
            data = messageData != nil ? String(data: try JSONEncoder.default.encode(messageData), encoding: .utf8) : nil
        case BlazeMessageAction.countSignalKeys.rawValue:
            let count = try container.decodeIfPresent(SignalKeyCount.self, forKey: .data)
            data = count != nil ? String(data: try JSONEncoder.default.encode(count), encoding: .utf8) : nil
        case BlazeMessageAction.consumeSignalKeys.rawValue, BlazeMessageAction.consumeSessionSignalKeys.rawValue:
            let keys = try container.decodeIfPresent([SignalKey].self, forKey: .data)
            data = keys != nil ? String(data: try JSONEncoder.default.encode(keys), encoding: .utf8) : nil
        case BlazeMessageAction.listKrakenPeers.rawValue:
            enum PeersCodingKeys: String, CodingKey {
                case peers
            }
            let peersContainer = try container.nestedContainer(keyedBy: PeersCodingKeys.self, forKey: .data)
            let peers = try peersContainer.decodeIfPresent([KrakenPeer].self, forKey: .peers) ?? []
            data = String(data: try JSONEncoder.default.encode(peers), encoding: .utf8)
        default:
            data = nil
        }
        
        params = try container.decodeIfPresent(BlazeMessageParam.self, forKey: .params)
        error = try container.decodeIfPresent(MixinAPIError.self, forKey: .error)
    }
    
}
