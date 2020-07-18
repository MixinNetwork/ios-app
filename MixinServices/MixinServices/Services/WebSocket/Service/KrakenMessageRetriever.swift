import Foundation

public protocol KrakenMessageRetrieverDelegate: class {
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
        
        do {
            let peers = try WebSocketService.shared.respondedMessage(for: blazeMessage).blazeMessage?.toKrakenPeers()
            return peers
        } catch let error as APIError where error.code == 20140 {
            SendMessageService.shared.syncConversation(conversationId: id)
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
        }
        
        queue.async {
            do {
                if let data = try WebSocketService.shared.respondedMessage(for: blazeMessage).blazeMessage?.toBlazeMessageData() {
                    completion?(.success(data))
                } else {
                    completion?(.failure(MixinServicesError.badKrakenBlazeMessage))
                }
            } catch let error as APIError where error.code == 20140 {
                if let conversationId = blazeMessage.params?.conversationId {
                    SendMessageService.shared.syncConversation(conversationId: conversationId)
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
