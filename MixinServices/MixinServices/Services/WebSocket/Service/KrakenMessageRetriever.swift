import Foundation

public protocol KrakenMessageRetrieverDelegate: AnyObject {
    func krakenMessageRetriever(_ retriever: KrakenMessageRetriever, shouldRetryRequest request: KrakenRequest, error: Swift.Error, numberOfRetries: UInt) -> Bool
}

public class KrakenMessageRetriever {
    
    public typealias Completion = (Result<BlazeMessageData, Error>) -> Void
    
    public static let shared = KrakenMessageRetriever()
    
    public weak var delegate: KrakenMessageRetrieverDelegate?
    
    private let queue = DispatchQueue(label: "one.mixin.service.KrakenMessageRetriever")
    
    public func request(_ request: KrakenRequest, completion: Completion?) {
        self.request(request, numberOfRetries: 0, completion: completion)
    }
    
    public func requestPeers(forConversationWith id: String) -> [KrakenPeer]? {
        var param = BlazeMessageParam()
        param.messageId = UUID().uuidString.lowercased()
        param.conversationId = id
        param.category = "KRAKEN_LIST"
        param.conversationChecksum = ConversationChecksumCalculator.checksum(conversationId: id)
        let blazeMessage = BlazeMessage(params: param, action: BlazeMessageAction.listKrakenPeers.rawValue)

        Logger.write(conversationId: id, log: "[KrakenMessageRetriever][RequestPeers]...listKrakenPeers...")
        do {
            let peers = try WebSocketService.shared.respondedMessage(for: blazeMessage).blazeMessage?.toKrakenPeers()
            return peers
        } catch MixinAPIError.invalidConversationChecksum {
            SendMessageService.shared.syncConversation(conversationId: id)
            try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: id)
            return requestPeers(forConversationWith: id)
        } catch {
            return nil
        }
    }
    
    private func request(_ request: KrakenRequest, numberOfRetries: UInt, completion: Completion?) {
        guard LoginManager.shared.isLoggedIn else {
            completion?(.failure(MixinServicesError.logout(isAsyncRequest: true)))
            return
        }
        
        var blazeMessage = request.blazeMessage
        if let conversationId = blazeMessage.params?.conversationId {
            let checksum = ConversationChecksumCalculator.checksum(conversationId: conversationId)
            blazeMessage.params?.conversationChecksum = checksum
            Logger.write(conversationId: conversationId, log: "[KrakenMessageRetriever][KrakenRequest]...\(blazeMessage.params?.category ?? "")")
        }
        
        queue.async {
            do {
                let blazeMessage = try WebSocketService.shared.respondedMessage(for: blazeMessage).blazeMessage
                if let data = blazeMessage?.toBlazeMessageData() {
                    completion?(.success(data))
                } else {
                    let error: Error = blazeMessage?.error ?? MixinServicesError.badKrakenBlazeMessage
                    completion?(.failure(error))
                }
            } catch MixinAPIError.invalidConversationChecksum {
                if let conversationId = blazeMessage.params?.conversationId {
                    SendMessageService.shared.syncConversation(conversationId: conversationId)
                    try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: conversationId)
                    self.request(request, completion: completion)
                } else {
                    completion?(.failure(MixinServicesError.missingConversationId))
                    assertionFailure()
                }
            } catch {
                self.queue.asyncAfter(deadline: .now() + 2) {
                    if let delegate = self.delegate, delegate.krakenMessageRetriever(self, shouldRetryRequest: request, error: error, numberOfRetries: numberOfRetries) {
                        self.request(request, numberOfRetries: numberOfRetries + 1, completion: completion)
                    } else {
                        completion?(.failure(error))
                    }
                }
            }
        }
    }
    
}
