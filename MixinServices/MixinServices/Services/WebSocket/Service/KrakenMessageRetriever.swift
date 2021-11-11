import Foundation

public protocol KrakenMessageRetrieverDelegate: AnyObject {
    func krakenMessageRetriever(_ retriever: KrakenMessageRetriever, shouldRetryRequest request: KrakenRequest, error: Swift.Error, numberOfRetries: UInt) -> Bool
}

public class KrakenMessageRetriever {
    
    public weak var delegate: KrakenMessageRetrieverDelegate?
    
    public init() {
        
    }
    
    @discardableResult
    public func request(_ request: KrakenRequest) -> Result<BlazeMessageData, Error> {
        self.request(request, numberOfRetries: 0)
    }
    
    public func requestPeers(forConversationWith id: String) -> [KrakenPeer]? {
        var param = BlazeMessageParam()
        param.messageId = UUID().uuidString.lowercased()
        param.conversationId = id
        param.category = "KRAKEN_LIST"
        param.conversationChecksum = ConversationChecksumCalculator.checksum(conversationId: id)
        let blazeMessage = BlazeMessage(params: param, action: BlazeMessageAction.listKrakenPeers.rawValue)
        
        Logger.call.info(category: "KrakenMessageRetriever", message: "Requesting peers for conversation: \(id)")
        do {
            if let peers = try WebSocketService.shared.respondedMessage(for: blazeMessage).blazeMessage?.toKrakenPeers() {
                return peers.filter { $0.userId != myUserId }
            } else {
                return nil
            }
        } catch MixinAPIError.invalidConversationChecksum {
            SendMessageService.shared.syncConversation(conversationId: id)
            try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: id)
            return requestPeers(forConversationWith: id)
        } catch {
            return nil
        }
    }
    
    private func request(_ request: KrakenRequest, numberOfRetries: UInt) -> Result<BlazeMessageData, Error> {
        guard LoginManager.shared.isLoggedIn else {
            return .failure(MixinServicesError.logout(isAsyncRequest: false))
        }
        
        var blazeMessage = request.blazeMessage
        if let conversationId = blazeMessage.params?.conversationId {
            let checksum = ConversationChecksumCalculator.checksum(conversationId: conversationId)
            blazeMessage.params?.conversationChecksum = checksum
        }
        
        do {
            let blazeMessage = try WebSocketService.shared.respondedMessage(for: blazeMessage).blazeMessage
            if let data = blazeMessage?.toBlazeMessageData() {
                return .success(data)
            } else {
                let error: Error = blazeMessage?.error ?? MixinServicesError.badKrakenBlazeMessage
                return .failure(error)
            }
        } catch MixinAPIError.invalidConversationChecksum {
            if let conversationId = blazeMessage.params?.conversationId {
                SendMessageService.shared.syncConversation(conversationId: conversationId)
                try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: conversationId)
                return self.request(request)
            } else {
                assertionFailure()
                return .failure(MixinServicesError.missingConversationId)
            }
        } catch {
            sleep(2)
            if let delegate = self.delegate, delegate.krakenMessageRetriever(self, shouldRetryRequest: request, error: error, numberOfRetries: numberOfRetries) {
                return self.request(request, numberOfRetries: numberOfRetries + 1)
            } else {
                return .failure(error)
            }
        }
    }
    
}
