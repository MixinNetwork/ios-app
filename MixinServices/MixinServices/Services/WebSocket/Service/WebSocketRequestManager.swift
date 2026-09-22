import Foundation

final class WebSocketRequestManager {
    
    typealias Completion = (Result<BlazeMessage, WebSocketService.SendingError>) -> Void
    
    private struct PendingRequest {
        let messageID: String
        let paramMessageID: String?
        let conversationID: String?
        let action: String
        let category: String?
        let completion: Completion
        let timer: (any DispatchSourceTimer)?
    }
    
    private let lock = NSLock()
    private let timerQueue = DispatchQueue(
        label: "one.mixin.services.websocket.request.timer",
        qos: .userInitiated
    )
    private var pendingRequests: [String: PendingRequest] = [:]
    
    func register(
        message: BlazeMessage,
        timeout: TimeInterval,
        completion: @escaping Completion,
    ) {
        let messageID = message.id
        let conversationID = message.params?.conversationId
        let category = message.params?.category
        let action = message.action
        
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { [weak self] in
            self?.handleTimeout(
                for: messageID,
                action: action,
                category: category,
                conversationID: conversationID,
                timeout: timeout,
            )
        }
        
        let pending = PendingRequest(
            messageID: messageID,
            paramMessageID: message.params?.messageId,
            conversationID: conversationID,
            action: action,
            category: category,
            completion: completion,
            timer: timer
        )
        
        lock.lock()
        pendingRequests[messageID] = pending
        lock.unlock()
        
        timer.resume()
    }
    
    @discardableResult
    func resolve(
        with message: BlazeMessage,
    ) -> Bool {
        lock.lock()
        guard let pending = pendingRequests.removeValue(forKey: message.id) else {
            lock.unlock()
            return false
        }
        lock.unlock()
        
        pending.timer?.cancel()
        
        if let error = message.error {
            if case .invalidRequestData = error {
                if let paramMessageID = pending.paramMessageID, paramMessageID != paramMessageID.lowercased() {
                    MessageDAO.shared.deleteMessage(id: paramMessageID)
                    JobDAO.shared.removeJob(jobId: pending.messageID)
                }
            }
            if let conversationID = pending.conversationID {
                Logger.conversation(id: conversationID).error(
                    category: "WebSocketRequestManager",
                    message: "Received response for \(pending.action), error: \(error)"
                )
            }
            pending.completion(.failure(.response(error)))
        } else {
            pending.completion(.success(message))
        }
        
        return true
    }
    
    @discardableResult
    func fail(
        messageID: String,
        with error: WebSocketService.SendingError,
    ) -> Bool {
        lock.lock()
        guard let pending = pendingRequests.removeValue(forKey: messageID) else {
            lock.unlock()
            return false
        }
        lock.unlock()
        
        pending.timer?.cancel()
        pending.completion(.failure(error))
        return true
    }
    
    func cancel(
        messageID: String,
    ) {
        lock.lock()
        guard let pending = pendingRequests.removeValue(forKey: messageID) else {
            lock.unlock()
            return
        }
        lock.unlock()
        
        pending.timer?.cancel()
    }
    
    func failAll(
        with error: WebSocketService.SendingError,
    ) {
        lock.lock()
        let requests = Array(pendingRequests.values)
        pendingRequests.removeAll()
        lock.unlock()
        
        for request in requests {
            request.timer?.cancel()
            request.completion(.failure(error))
        }
    }
    
    private func handleTimeout(
        for messageID: String,
        action: String,
        category: String?,
        conversationID: String?,
        timeout: TimeInterval,
    ) {
        lock.lock()
        guard let pending = pendingRequests.removeValue(forKey: messageID) else {
            lock.unlock()
            return
        }
        lock.unlock()
        
        pending.timer?.cancel()
        
        let categoryName = category ?? "(null)"
        let log = "Response timed out for action: \(action), category: \(categoryName), timeout: \(timeout)s"
        if let conversationID {
            Logger.conversation(id: conversationID).error(
                category: "WebSocketRequestManager",
                message: log
            )
        } else {
            Logger.general.error(
                category: "WebSocketRequestManager",
                message: log
            )
        }
        
        pending.completion(.failure(.timedOut))
    }
    
}
