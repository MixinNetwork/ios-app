import Foundation
import GRDB

public class SendMessageService: MixinService {
    
    public static let shared = SendMessageService()
    
    internal static let recallableSuffices = [
        "_TEXT", "_STICKER", "_CONTACT", "_IMAGE", "_DATA",
        "_AUDIO", "_VIDEO", "_LIVE", "_POST", "_LOCATION",
        "_TRANSCRIPT"
    ]
    
    public let jobCreationQueue = DispatchQueue(label: "one.mixin.services.queue.send.message.job.creation")
    
    private let dispatchQueue = DispatchQueue(label: "one.mixin.services.queue.send.messages")
    private let httpDispatchQueue = DispatchQueue(label: "one.mixin.services.queue.send.http.messages")
    private var httpProcessing = false
    
    public func sendPinMessages(items: [MessageItem], conversationId: String, action: TransferPinAction) {
        DispatchQueue.global().async {
            let messageId = UUID().uuidString.lowercased()
            let pinMessageIds = items.map(\.messageId)
            let blazeMessage = BlazeMessage(messageId: messageId, pinMessageIds: pinMessageIds, conversationId: conversationId, action: action)
            let job = Job(jobId: UUID().uuidString.lowercased(), action: JobAction.SEND_MESSAGE, conversationId: conversationId, blazeMessage: blazeMessage)
            JobDAO.shared.insertOrIgnore(job)
            SendMessageService.shared.processMessages()
            switch action {
            case .pin:
                guard let item = items.first else {
                    return
                }
                let mention: MessageMention?
                if item.category.hasSuffix("_TEXT"), let content = item.content {
                    mention = MessageMention(conversationId: item.conversationId,
                                             messageId: messageId,
                                             content: content,
                                             addMeIntoMentions: false,
                                             hasRead: { _ in true })
                } else {
                    mention = nil
                }
                let pinLocalContent = PinMessage.LocalContent(category: item.category, content: item.content)
                let content: String
                if let data = try? JSONEncoder.default.encode(pinLocalContent), let localContent = String(data: data, encoding: .utf8) {
                    content = localContent
                } else {
                    content = ""
                }
                let message = Message.createMessage(messageId: messageId,
                                                    conversationId: item.conversationId,
                                                    userId: myUserId,
                                                    category: MessageCategory.MESSAGE_PIN.rawValue,
                                                    content: content,
                                                    status: MessageStatus.DELIVERED.rawValue,
                                                    action: action.rawValue,
                                                    quoteMessageId: item.messageId,
                                                    createdAt: Date().toUTCString())
                PinMessageDAO.shared.save(referencedItem: item,
                                          source: MessageCategory.MESSAGE_PIN.rawValue,
                                          silentNotification: true,
                                          pinMessage: message,
                                          mention: mention)
            case .unpin:
                PinMessageDAO.shared.delete(messageIds: pinMessageIds, conversationId: conversationId)
            }
        }
    }
    
    public func recallMessage(item: MessageItem) {
        let category = item.category
        let conversationId = item.conversationId
        let messageId = item.messageId
        guard category == MessageCategory.APP_CARD.rawValue || SendMessageService.recallableSuffices.contains(where: category.hasSuffix) else {
            return
        }
        
        let blazeMessage = BlazeMessage(recallMessageId: messageId, conversationId: conversationId)
        let job = Job(jobId: UUID().uuidString.lowercased(), action: JobAction.SEND_MESSAGE, conversationId: conversationId, blazeMessage: blazeMessage)
        
        ReceiveMessageService.shared.stopRecallMessage(item: item)
        
        let database: Database = UserDatabase.current
        let quoteCondition: SQLSpecificExpressible = Message.column(of: .conversationId) == conversationId
            && Message.column(of: .quoteMessageId) == messageId
        let quoteMessageIds: [String] = database.select(column: Message.column(of: .messageId),
                                                        from: Message.self,
                                                        where: quoteCondition)
        database.write { (db) in
            try job.save(db)
            try MessageDAO.shared.recallMessage(database: db,
                                                messageId: messageId,
                                                conversationId: conversationId,
                                                category: category,
                                                status: item.status,
                                                quoteMessageIds: quoteMessageIds)
        }
        SendMessageService.shared.processMessages()
    }
    
    public func sendMessage(message: Message, data: String?, immediatelySend: Bool = true, silentNotification: Bool = false, expireIn: Int64 = 0) {
        let needsEncodeCategories: [MessageCategory] = [
            .PLAIN_TEXT, .PLAIN_POST, .PLAIN_LOCATION, .PLAIN_TRANSCRIPT
        ]
        let shouldEncodeContent = needsEncodeCategories.map(\.rawValue).contains(message.category)
        let content = shouldEncodeContent ? data?.base64Encoded() : data
        let job = Job(message: message, data: content, silentNotification: silentNotification, expireIn: expireIn)
        JobDAO.shared.insertOrIgnore(job)
        if immediatelySend {
            SendMessageService.shared.processMessages()
        }
    }
    
    @discardableResult
    public func saveUploadJob(message: Message) -> String {
        let job: Job
        if message.category.hasSuffix("_TRANSCRIPT") {
            job = Job(attachmentMessage: message.messageId, action: .UPLOAD_TRANSCRIPT_ATTACHMENT)
        } else {
            job = Job(attachmentMessage: message.messageId, action: .UPLOAD_ATTACHMENT)
        }
        JobDAO.shared.insertOrIgnore(job)
        return job.jobId
    }
    
    public func recoverAttachmentMessages(messageIds: [String]) {
        let jobs = messageIds.map { Job(attachmentMessage: $0, action: .RECOVER_ATTACHMENT) }
        JobDAO.shared.insertOrIgnore(jobs)
    }
    
    // A `conversation_id` is required here to compose a BlazeMessage.
    // Since it doesn't have any practical significance, you can pass in any valid conversation ID.
    // The `session_id` is the recipient's session ID, typically is the one of desktop client.
    public func sendDeviceTransferCommand(_ content: String, conversationId: String, sessionId: String, completion: @escaping (Bool) -> Void) {
        dispatchQueue.async {
            var params = BlazeMessageParam()
            params.conversationId = conversationId
            params.recipientId = myUserId
            params.messageId = UUID().uuidString.lowercased()
            params.category = MessageCategory.PLAIN_JSON.rawValue
            params.data = {
                let transferPlainData = PlainJsonMessagePayload(action: PlainDataAction.DEVICE_TRANSFER.rawValue, messages: nil, ackMessages: nil, content: content)
                let encoded = (try? JSONEncoder.default.encode(transferPlainData).base64RawURLEncodedString()) ?? ""
                return encoded
            }()
            params.status = MessageStatus.SENDING.rawValue
            params.sessionId = sessionId
            let blazeMessage = BlazeMessage(id: UUID().uuidString.lowercased(),
                                            action: BlazeMessageAction.createMessage.rawValue,
                                            params: params,
                                            data: nil,
                                            error: nil,
                                            fromPush: nil)
            WebSocketService.shared.send(message: blazeMessage) { success in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
            Logger.general.info(category: "SendMessageService", message: "Send Command, content:\(content) conversationId:\(conversationId) sessionId:\(sessionId). BlazeMessage: \(blazeMessage)")
        }
    }
    
    public func sendWebRTCMessage(message: Message, recipientId: String) {
        let job = Job(webRTCMessage: message, recipientId: recipientId)
        JobDAO.shared.insertOrIgnore(job)
        SendMessageService.shared.processMessages()
    }
    
    func sendMessage(conversationId: String, userId: String, sessionId: String?, action: JobAction) {
        let job = Job(jobId: UUID().uuidString.lowercased(), action: action, userId: userId, conversationId: conversationId, sessionId: sessionId)
        JobDAO.shared.insertOrIgnore(job)
        SendMessageService.shared.processMessages()
    }
    
    func sendMessage(conversationId: String, userId: String, blazeMessage: BlazeMessage, action: JobAction) {
        let job = Job(jobId: blazeMessage.id, action: action, userId: userId, conversationId: conversationId, blazeMessage: blazeMessage)
        JobDAO.shared.insertOrIgnore(job)
        SendMessageService.shared.processMessages()
    }
    
    public func resendMessages(conversationId: String, userId: String, sessionId: String, messageIds: [String]) {
        guard let participent = ParticipantDAO.shared.getParticipent(conversationId: conversationId, userId: userId) else {
            return
        }
        
        var jobs = [Job]()
        var resendMessages = [ResendSessionMessage]()
        for messageId in messageIds {
            guard !ResendSessionMessageDAO.shared.isExist(messageId: messageId, userId: userId, sessionId: sessionId) else {
                continue
            }
            guard let needResendMessage = MessageDAO.shared.getMessage(messageId: messageId, userId: currentAccountId), needResendMessage.category != MessageCategory.MESSAGE_RECALL.rawValue else {
                resendMessages.append(ResendSessionMessage(messageId: messageId, userId: userId, sessionId: sessionId, status: 0))
                continue
            }
            guard needResendMessage.category.hasPrefix("SIGNAL_") else {
                continue
            }
            guard needResendMessage.createdAt > participent.createdAt else {
                continue
            }
            
            let param = BlazeMessageParam(conversationId: conversationId, recipientId: userId, status: MessageStatus.SENT.rawValue, messageId: messageId, sessionId: sessionId)
            let blazeMessage = BlazeMessage(params: param, action: BlazeMessageAction.createMessage.rawValue)
            jobs.append(Job(jobId: blazeMessage.id, action: .RESEND_MESSAGE, userId: userId, conversationId: conversationId, resendMessageId: UUID().uuidString.lowercased(), sessionId: sessionId, blazeMessage: blazeMessage))
            resendMessages.append(ResendSessionMessage(messageId: messageId, userId: userId, sessionId: sessionId, status: 1))
        }
        
        UserDatabase.current.write { (db) in
            try jobs.save(db)
            try resendMessages.save(db)
        }
        SendMessageService.shared.processMessages()
    }
    
    public func sendReadMessages(conversationId: String) {
        DispatchQueue.global().async {
            let unreadMessages = MessageDAO.shared.getUnreadMessages(conversationId: conversationId)
            var position = 0
            let pageCount = AppGroupUserDefaults.Account.isDesktopLoggedIn ? 1000 : 2000
            if unreadMessages.count == 0 {
                UserDatabase.current.write { (db) in
                    let unseenMessageCountSQL = "SELECT unseen_message_count FROM \(Conversation.databaseTableName) WHERE conversation_id = ?"
                    if let unseenMessageCount = try Int.fetchOne(db, sql: unseenMessageCountSQL, arguments: [conversationId]), unseenMessageCount > 0 {
                        try MessageDAO.shared.updateUnseenMessageCount(database: db, conversationId: conversationId)
                    }
                }
            }
            while unreadMessages.count > 0 && position < unreadMessages.count {
                let nextPosition = position + pageCount > unreadMessages.count ? unreadMessages.count : position + pageCount
                let messages = Array(unreadMessages[position..<nextPosition])
                var jobs = [Job]()
                
                guard let lastMessageId = messages.last?.id,
                      let lastRowID: Int = UserDatabase.current.select(column: .rowID, from: Message.self, where: Message.column(of: .messageId) == lastMessageId)
                else {
                    return
                }
                let expireAts: [String: Int64] = messages.reduce(into: [:]) { result, message in
                    if message.expireAt == nil, let expireIn = message.expireIn {
                        let expireAt = Int64(Date().timeIntervalSince1970) + expireIn
                        result[message.id] = expireAt
                    }
                }
                if messages.count == 1 {
                    let message = messages[0]
                    let transferMessage = TransferMessage(messageId: message.id, status: MessageStatus.READ.rawValue, expireAt: message.expireAt ?? expireAts[message.id])
                    let blazeMessage = BlazeMessage(params: BlazeMessageParam(messages: [transferMessage]), action: BlazeMessageAction.acknowledgeMessageReceipts.rawValue)
                    jobs.append(Job(jobId: blazeMessage.id, action: .SEND_ACK_MESSAGES, blazeMessage: blazeMessage))
                    
                    if AppGroupUserDefaults.Account.isDesktopLoggedIn {
                        jobs.append(Job(sessionRead: conversationId, messageId: message.id))
                    }
                } else {
                    for i in stride(from: 0, to: messages.count, by: 100) {
                        let by = i + 100 > messages.count ? messages.count : i + 100
                        let transferMessages: [TransferMessage] = messages[i..<by].map { TransferMessage(messageId: $0.id, status: MessageStatus.READ.rawValue, expireAt: $0.expireAt ?? expireAts[$0.id]) }
                        let blazeMessage = BlazeMessage(params: BlazeMessageParam(messages: transferMessages), action: BlazeMessageAction.acknowledgeMessageReceipts.rawValue)
                        jobs.append(Job(jobId: blazeMessage.id, action: .SEND_ACK_MESSAGES, blazeMessage: blazeMessage))
                        
                        if let sessionId = AppGroupUserDefaults.Account.extensionSession {
                            let blazeMessage = BlazeMessage(params: BlazeMessageParam(sessionId: sessionId, conversationId: conversationId, ackMessages: transferMessages), action: BlazeMessageAction.createMessage.rawValue)
                            jobs.append(Job(jobId: blazeMessage.id, action: .SEND_SESSION_MESSAGES, blazeMessage: blazeMessage))
                        }
                    }
                }
                
                let isLastLoop = nextPosition >= messages.count
                UserDatabase.current.write { (db) in
                    try jobs.insert(db)
                    try db.execute(sql: "UPDATE messages SET status = '\(MessageStatus.READ.rawValue)' WHERE conversation_id = ? AND status = ? AND user_id != ? AND ROWID <= ?",
                                   arguments: [conversationId, MessageStatus.DELIVERED.rawValue, myUserId, lastRowID])
                    try MessageDAO.shared.updateUnseenMessageCount(database: db, conversationId: conversationId)
                    try ConversationDAO.shared.updateLastReadMessageId(lastMessageId, conversationId: conversationId, database: db)
                    try ExpiredMessageDAO.shared.updateExpireAts(expireAts: expireAts, database: db)
                    if isLastLoop {
                        db.afterNextTransaction { (_) in
                            NotificationCenter.default.post(name: MixinService.messageReadStatusDidChangeNotification, object: self)
                            NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: nil)
                        }
                    }
                }
                
                position = nextPosition
                if !isLastLoop {
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
            SendMessageService.shared.processMessages()
        }
    }
    
    public func sendMentionMessageRead(conversationId: String, messageId: String) {
        UserDatabase.current.write { (db) in
            let condition: SQLSpecificExpressible = MessageMention.column(of: .messageId) == messageId
                && !MessageMention.column(of: .hasRead)
            let changes = try MessageMention.filter(condition).updateAll(db, [MessageMention.column(of: .hasRead).set(to: true)])
            
            guard changes > 0 else {
                return
            }
            
            db.afterNextTransaction { (_) in
                NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: nil)
            }

            if AppGroupUserDefaults.Account.isDesktopLoggedIn {
                let job = Job(sessionRead: conversationId, messageId: messageId, status: MessageMentionStatus.MENTION_READ.rawValue)
                try job.save(db)
            }
        }
    }
    
    public func sendAckMessage(messageId: String, status: MessageStatus) {
        let blazeMessage = BlazeMessage(ackBlazeMessage: messageId, status: status.rawValue)
        let action: JobAction = status == .DELIVERED ? .SEND_DELIVERED_ACK_MESSAGE : .SEND_ACK_MESSAGE
        let jobId = (messageId + status.rawValue + action.rawValue).uuidDigest()
        let job = Job(jobId: jobId, action: action, blazeMessage: blazeMessage)
        JobDAO.shared.insertOrIgnore(job)
        SendMessageService.shared.processMessages()
    }
    
    public func processMessages() {
        processHttpMessages()
        if !isAppExtension {
            processWebSocketMessages()
        }
    }
    
    public func processHttpMessages() {
        guard !httpProcessing else {
            return
        }
        httpProcessing = true
        
        httpDispatchQueue.async {
            defer {
                SendMessageService.shared.httpProcessing = false
            }
            repeat {
                guard LoginManager.shared.isLoggedIn else {
                    return
                }
                guard !MixinService.isStopProcessMessages else {
                    return
                }
                
                let jobs = JobDAO.shared.nextBatchJobs(category: .Http, limit: 100)
                var ackMessages = [AckMessage]()
                jobs.forEach { (job) in
                    switch job.action {
                    case JobAction.SEND_ACK_MESSAGE.rawValue, JobAction.SEND_DELIVERED_ACK_MESSAGE.rawValue:
                        if let params = job.toBlazeMessage().params, let messageId = params.messageId, let status = params.status {
                            ackMessages.append(AckMessage(jobId: job.jobId, messageId: messageId, status: status))
                        }
                    case JobAction.SEND_ACK_MESSAGES.rawValue:
                        if let messages = job.toBlazeMessage().params?.messages {
                            ackMessages += messages.map { AckMessage(jobId: job.jobId, messageId: $0.messageId, status: $0.status!) }
                        }
                    default:
                        break
                    }
                }
                
                guard ackMessages.count > 0 else {
                    JobDAO.shared.removeJobs(jobIds: jobs.map{ $0.jobId })
                    return
                }
                
                for i in stride(from: 0, to: ackMessages.count, by: 100) {
                    let by = i + 100 > ackMessages.count ? ackMessages.count : i + 100
                    let messages = Array(ackMessages[i..<by])
                    if SendMessageService.shared.sendAckMessages(ackMessages: messages) {
                        JobDAO.shared.removeJobs(jobIds: messages.map{ $0.jobId })
                    } else {
                        return
                    }
                }
            } while true
        }
    }
    
    private func sendAckMessages(ackMessages: [AckMessage]) -> Bool {
        repeat {
            switch MessageAPI.acknowledgements(ackMessages: ackMessages) {
            case .success:
                return true
            case .failure(.unauthorized):
                return false
            case .failure(.forbidden):
                return true
            case .failure:
                checkNetwork()
            }
        } while true
    }
    
    public func processWebSocketMessages() {
        guard !processing else {
            return
        }
        processing = true
        
        dispatchQueue.async {
            defer {
                SendMessageService.shared.processing = false
            }
            var deleteJobId = ""
            repeat {
                guard LoginManager.shared.isLoggedIn else {
                    return
                }
                guard !MixinService.isStopProcessMessages else {
                    return
                }
                guard let job = JobDAO.shared.nextJob(category: .WebSocket) else {
                    return
                }
                
                if job.action == JobAction.SEND_SESSION_MESSAGE.rawValue {
                    guard let sessionId = AppGroupUserDefaults.Account.extensionSession else {
                        JobDAO.shared.removeJob(jobId: job.jobId)
                        continue
                    }
                    let jobs = JobDAO.shared.nextBatchJobs(category: .WebSocket, action: .SEND_SESSION_MESSAGE, limit: 100)
                    let messages: [TransferMessage] = jobs.compactMap {
                        guard let messageId = $0.messageId, let status = $0.status else {
                            return nil
                        }
                        return TransferMessage(messageId: messageId, status: status)
                    }
                    
                    guard messages.count > 0, let conversationId = jobs.first?.conversationId else {
                        JobDAO.shared.removeJobs(jobIds: jobs.map{ $0.jobId })
                        continue
                    }
                    
                    let blazeMessage = BlazeMessage(params: BlazeMessageParam(sessionId: sessionId, conversationId: conversationId, ackMessages: messages), action: BlazeMessageAction.createMessage.rawValue)
                    if SendMessageService.shared.deliverLowPriorityMessages(blazeMessage: blazeMessage) {
                        JobDAO.shared.removeJobs(jobIds: jobs.map{ $0.jobId })
                    }
                } else {
                    if deleteJobId == job.jobId {
                        reporter.report(error: MixinServicesError.duplicatedJob)
                    }
                    guard SendMessageService.shared.handlerJob(job: job) else {
                        return
                    }
                    
                    deleteJobId = job.jobId
                    JobDAO.shared.removeJob(jobId: job.jobId)
                }
            } while true
        }
    }
    
    private func deliverLowPriorityMessages(blazeMessage: BlazeMessage) -> Bool {
        do {
            return try WebSocketService.shared.respondedMessage(for: blazeMessage) != nil
        } catch MixinAPIResponseError.unauthorized {
            return false
        } catch MixinAPIResponseError.forbidden {
            return true
        } catch {
            switch error as? WebSocketService.SendingError {
            case .timedOut:
                break
            case .response(let error) where error.isClientErrorResponse:
                Thread.sleep(forTimeInterval: 2)
            default:
                reporter.report(error: error)
            }
            
            while LoginManager.shared.isLoggedIn && (!ReachabilityManger.shared.isReachable || !WebSocketService.shared.isConnected) {
                Thread.sleep(forTimeInterval: 2)
            }
            return false
        }
    }
    
    private func handlerJob(job: Job) -> Bool {
        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return false
            }
            guard !MixinService.isStopProcessMessages else {
                return false
            }
            
            do {
                switch job.action {
                case JobAction.SEND_MESSAGE.rawValue:
                    try ReceiveMessageService.shared.messageDispatchQueue.sync {
                        let blazeMessage = job.toBlazeMessage()
                        if blazeMessage.action == BlazeMessageAction.createCall.rawValue {
                            try SendMessageService.shared.sendCallMessage(blazeMessage: blazeMessage)
                        } else if blazeMessage.params?.category == MessageCategory.MESSAGE_PIN.rawValue {
                            try SendMessageService.shared.sendPinMessage(blazeMessage: blazeMessage)
                        } else {
                            try SendMessageService.shared.sendMessage(blazeMessage: blazeMessage)
                        }
                    }
                case JobAction.RESEND_MESSAGE.rawValue:
                    try ReceiveMessageService.shared.messageDispatchQueue.sync {
                        try SendMessageService.shared.resendMessage(job: job)
                    }
                case JobAction.SEND_SESSION_MESSAGES.rawValue:
                    deliverNoThrow(blazeMessage: job.toBlazeMessage())
                case JobAction.REFRESH_SESSION.rawValue:
                    _ = ReceiveMessageService.shared.messageDispatchQueue.sync { () -> Bool in
                        let result = refreshParticipantSession(conversationId: job.conversationId!, userId: job.userId!, retry: true)
                        let userInfo = [
                            ReceiveMessageService.UserInfoKey.conversationId: job.conversationId,
                            ReceiveMessageService.UserInfoKey.userId: job.userId
                        ]
                        NotificationCenter.default.post(name: ReceiveMessageService.senderKeyDidChangeNotification, object: self, userInfo: userInfo)
                        return result
                    }
                case JobAction.RESEND_KEY.rawValue:
                    try ReceiveMessageService.shared.messageDispatchQueue.sync {
                        guard let conversationId = job.conversationId, let recipientId = job.userId, let sessionId = job.sessionId else {
                            return
                        }
                        
                        let result = try sendSenderKey(conversationId: conversationId, recipientId: recipientId, sessionId: sessionId)
                        if !result {
                            Logger.conversation(id: conversationId).info(category: "ResendSenderKey", message: "Received no group signal key for recipient: \(recipientId)")
                            sendNoKeyMessage(conversationId: conversationId, recipientId: recipientId)
                        }
                    }
                case JobAction.REQUEST_RESEND_KEY.rawValue:
                    ReceiveMessageService.shared.messageDispatchQueue.sync {
                        let blazeMessage = job.toBlazeMessage()
                        deliverNoThrow(blazeMessage: blazeMessage)
                        let messageId = blazeMessage.params?.messageId ?? "(null)"
                        Logger.conversation(id: job.conversationId!).info(category: "SendMessageService", message: "Request resend key for message: \(messageId)")
                    }
                case JobAction.REQUEST_RESEND_MESSAGES.rawValue:
                    deliverNoThrow(blazeMessage: job.toBlazeMessage())
                case JobAction.SEND_NO_KEY.rawValue:
                    deliverNoThrow(blazeMessage: job.toBlazeMessage())
                default:
                    break
                }
                return true
            } catch {
                checkNetworkAndWebSocket()
                switch error {
                case let error as MixinAPIError where error.isTransportTimedOut:
                    // TODO: Guess this case will never match
                    break
                case WebSocketService.SendingError.timedOut:
                    break
                default:
                    var blazeMessage = ""
                    var conversationId = job.conversationId ?? ""
                    if let bm = job.blazeMessage {
                        blazeMessage = String(data: bm, encoding: .utf8) ?? ""
                        if conversationId.isEmpty {
                            conversationId = job.toBlazeMessage().params?.conversationId ?? ""
                        }
                    }
                    
                    var userInfo = [String: Any]()
                    userInfo["errorCode"] = (error as NSError).code
                    userInfo["errorDescription"] = error.localizedDescription
                    userInfo["JobAction"] = job.action
                    userInfo["conversationId"] = conversationId
                    if !conversationId.isEmpty && job.action == JobAction.SEND_MESSAGE.rawValue {
                        if let conversationName = ConversationDAO.shared.getConversation(conversationId: conversationId)?.name {
                            userInfo["conversationName"] = conversationName
                        }
                    }
                    userInfo["blazeMessage"] = blazeMessage
                    if let err = error as? SignalError {
                        userInfo["signalErrorCode"] = err.rawValue
                        if IdentityDAO.shared.getLocalIdentity() == nil {
                            userInfo["signalError"] = "local identity nil"
                            userInfo["identityCount"] = "\(IdentityDAO.shared.getCount())"
                            Logger.general.error(category: "SendMessageService", message: "Job execution failed: \(err)", userInfo: userInfo)
                            reporter.report(error: MixinServicesError.sendMessage(userInfo))
                            LoginManager.shared.logout(reason: "SendMessage: \(err), userinfo: \(userInfo)")
                            return false
                        }
                    }
                    Logger.general.error(category: "SendMessageService", message: "Job execution failed: \(error)", userInfo: userInfo)
                    reporter.report(error: MixinServicesError.sendMessage(userInfo))
                }
                
                if case MixinAPIResponseError.invalidRequestData = error {
                    return true
                }
            }
        } while true
    }
}

extension SendMessageService {
    
    // When a text message is sent to group with format "^@700\d* ", it will be send directly to the app if the app is in the group
    public func groupMessageRecipientAppId(_ content: String, conversationId: String) -> String? {
        guard content.hasPrefix("@700"), let botNumberRange = content.range(of: #"^@700\d* "#, options: .regularExpression) else {
            return nil
        }
        let identityNumber = content[botNumberRange].dropFirstAndLast()
        if let recipientId = ParticipantDAO.shared.getParticipantId(conversationId: conversationId, identityNumber: identityNumber), !recipientId.isEmpty {
            return recipientId
        } else {
            return nil
        }
    }
    
    private func resendMessage(job: Job) throws {
        var blazeMessage = job.toBlazeMessage()
        guard let messageId = blazeMessage.params?.messageId, let resendMessageId = job.resendMessageId, let recipientId = job.userId else {
            return
        }
        guard let message = MessageDAO.shared.getMessage(messageId: messageId), try checkSignalSession(recipientId: recipientId, sessionId: job.sessionId) else {
            return
        }
        
        blazeMessage.params?.category = message.category
        blazeMessage.params?.messageId = resendMessageId
        blazeMessage.params?.quoteMessageId = message.quoteMessageId
        blazeMessage.params?.data = try SignalProtocol.shared.encryptSessionMessageData(recipientId: recipientId, content: message.content ?? "", resendMessageId: messageId, sessionId: job.sessionId)
        try deliverMessage(blazeMessage: blazeMessage)
        
        Logger.conversation(id: message.conversationId).info(category: "SendMessageService", message: "Resend message: \(messageId), resendMessageId:\(resendMessageId), recipientId:\(recipientId)")
    }
    
    private func sendMessage(blazeMessage: BlazeMessage) throws {
        var blazeMessage = blazeMessage
        guard let messageId = blazeMessage.params?.messageId, var message = MessageDAO.shared.getMessage(messageId: messageId) else {
            return
        }
        guard let conversation = ConversationDAO.shared.getConversation(conversationId: message.conversationId) else {
            return
        }
        if conversation.isGroup() && conversation.status != ConversationStatus.SUCCESS.rawValue {
            var userInfo = [String: Any]()
            userInfo["error"] = "conversation status error"
            userInfo["conversationStatus"] = "\(conversation.status)"
            userInfo["conversationId"] = "\(message.conversationId)"
            reporter.report(error: MixinServicesError.sendMessage(userInfo))
            return
        }
        
        if message.category.hasSuffix("_TEXT"), let text = message.content {
            if conversation.category == ConversationCategory.GROUP.rawValue, let recipientId = groupMessageRecipientAppId(text, conversationId: conversation.conversationId) {
                blazeMessage.params?.recipientId = recipientId
                blazeMessage.params?.data = nil
            } else {
                let numbers = MessageMentionDetector.identityNumbers(from: text).filter { $0 != myIdentityNumber }
                if numbers.count > 0 {
                    let userIds = UserDAO.shared.userIds(identityNumbers: numbers)
                    blazeMessage.params?.mentions = userIds
                }
            }
        }
        
        if message.category == MessageCategory.MESSAGE_RECALL.rawValue {
            blazeMessage.params?.messageId = UUID().uuidString.lowercased()
        } else {
            blazeMessage.params?.category = message.category
            blazeMessage.params?.quoteMessageId = message.quoteMessageId
        }
        
        let needsEncodeCategories: [MessageCategory] = [
            .PLAIN_TEXT, .PLAIN_POST, .PLAIN_LOCATION, .PLAIN_TRANSCRIPT
        ]
        func checkConversationAndExpireIn() throws {
            let expireIn = try checkConversationExist(conversation: conversation)
            if blazeMessage.params?.expireIn == 0, expireIn != 0 {
                blazeMessage.params?.expireIn = expireIn
                ExpiredMessageDAO.shared.insert(message: ExpiredMessage(messageId: messageId, expireIn: expireIn),
                                                     conversationId: message.conversationId)
            }
        }
        if message.category.hasPrefix("PLAIN_") || message.category == MessageCategory.MESSAGE_RECALL.rawValue || message.category == MessageCategory.APP_CARD.rawValue {
            try checkConversationAndExpireIn()
            if blazeMessage.params?.data == nil {
                if needsEncodeCategories.map(\.rawValue).contains(message.category) {
                    blazeMessage.params?.data = message.content?.base64Encoded()
                } else {
                    blazeMessage.params?.data = message.content
                }
            }
        } else if message.category.hasPrefix("ENCRYPTED_") {
            // FIXME: Participant session saving may not finished after the func below returns.
            // This may cause a few PLAIN messages sent out instead of ENCRYPTED ones
            try checkConversationAndExpireIn()
            func getBotSessionKey() -> ParticipantSession.Key? {
                if let id = blazeMessage.params?.recipientId {
                    return ParticipantSessionDAO.shared.getParticipantSessionKey(conversationId: message.conversationId, userId: id)
                } else {
                    return ParticipantSessionDAO.shared.getParticipantSessionKeyWithoutSelf(conversationId: message.conversationId, userId: myUserId)
                }
            }
            
            var participantSessionKey = getBotSessionKey()
            if participantSessionKey == nil || participantSessionKey?.publicKey == nil {
                syncConversation(conversationId: message.conversationId)
                participantSessionKey = getBotSessionKey()
            }
            
            func sendPlainMessage() throws {
                let newCategory = message.category.replacingOccurrences(of: "ENCRYPTED_", with: "PLAIN_")
                MessageDAO.shared.updateMessageCategory(newCategory, forMessageWithId: message.messageId)
                blazeMessage.params?.category = newCategory
                if let data = blazeMessage.params?.data, needsEncodeCategories.map(\.rawValue).contains(newCategory) {
                    blazeMessage.params?.data = data.base64Encoded()
                }
                try sendMessage(blazeMessage: blazeMessage)
            }
            
            let rawContent = blazeMessage.params?.data ?? message.content ?? ""
            let contentData: Data?
            if ["_IMAGE", "_VIDEO", "_STICKER", "_DATA", "_CONTACT", "_AUDIO", "_LIVE"].contains(where: message.category.hasSuffix) {
                contentData = Data(base64Encoded: rawContent)
            } else {
                contentData = rawContent.data(using: .utf8)
            }
            guard
                let contentData = contentData,
                let privateKey = RequestSigning.edDSAPrivateKey,
                let publicKeyBase64 = participantSessionKey?.publicKey,
                let publicKey = Data(base64URLEncoded: publicKeyBase64),
                let sid = participantSessionKey?.sessionId,
                let sessionId = UUID(uuidString: sid)
            else {
                try sendPlainMessage()
                let maybePublicKey = participantSessionKey?.publicKey ?? ""
                let maybePublicKeyData = Data(base64URLEncoded: maybePublicKey) ?? Data()
                let maybeSessionId = participantSessionKey?.sessionId ?? ""
                let info = [
                    "has_content": contentData != nil,
                    "has_pk": RequestSigning.edDSAPrivateKey != nil,
                    "has_psk": participantSessionKey != nil,
                    "has_pub": !maybePublicKey.isEmpty,
                    "is_pub_valid": !maybePublicKeyData.isEmpty,
                    "has_sid": !maybeSessionId.isEmpty,
                    "is_sid_valid": UUID(uuidString: maybeSessionId) != nil
                ]
                Logger.conversation(id: message.conversationId).error(category: "EncryptedBotMessage", message: "Failed to encrypt", userInfo: info)
                reporter.report(error: MixinServicesError.encryptBotMessage(info))
                return
            }
            let extensionSession: (id: UUID, key: Data)?
            if let id = AppGroupUserDefaults.Account.extensionSession {
                guard
                    let sessionId = UUID(uuidString: id),
                    let publicKeyBase64 = ParticipantSessionDAO.shared.getParticipantSession(conversationId: message.conversationId, userId: myUserId, sessionId: id)?.publicKey,
                    let publicKey = Data(base64URLEncoded: publicKeyBase64)
                else {
                    try sendPlainMessage()
                    let publicKeyBase64 = ParticipantSessionDAO.shared.getParticipantSession(conversationId: message.conversationId, userId: myUserId, sessionId: id)?.publicKey ?? ""
                    let publicKeyData = Data(base64URLEncoded: publicKeyBase64) ?? Data()
                    let info = [
                        "is_sid_valid": UUID(uuidString: id) != nil,
                        "has_pub": !publicKeyBase64.isEmpty,
                        "is_pub_valid": !publicKeyData.isEmpty
                    ]
                    Logger.conversation(id: message.conversationId).error(category: "EncryptedBotMessage", message: "Failed to encrypt for extension session", userInfo: info)
                    reporter.report(error: MixinServicesError.encryptBotMessage(info))
                    return
                }
                extensionSession = (id: sessionId, key: publicKey)
            } else {
                extensionSession = nil
            }
            let content = try EncryptedProtocol.encrypt(contentData, with: privateKey, remotePublicKey: publicKey, remoteSessionID: sessionId, extensionSession: extensionSession)
            blazeMessage.params?.data = content.base64EncodedString()
        } else {
            if !SignalProtocol.shared.isExistSenderKey(groupId: message.conversationId, senderId: message.userId) {
                if conversation.isGroup() {
                    syncConversation(conversationId: message.conversationId)
                } else {
                    try checkConversationAndExpireIn()
                }
            } else {
                try checkConversationAndExpireIn()
            }
            try checkSessionSenderKey(conversationId: message.conversationId)
            
            let content = blazeMessage.params?.data ?? message.content ?? ""
            blazeMessage.params?.data = try SignalProtocol.shared.encryptGroupMessageData(conversationId: message.conversationId, senderId: message.userId, content: content)
        }
        
        try deliverMessage(blazeMessage: blazeMessage)
        Logger.conversation(id: message.conversationId).info(category: "SendMessageService", message: "Send message: \(messageId), category:\(message.category), status:\(message.status)")
    }
        
    private func checkConversationExist(conversation: ConversationItem) throws -> Int64 {
        if conversation.status == ConversationStatus.START.rawValue {
            return try createConversation(conversation: conversation)
        } else {
            return conversation.expireIn
        }
    }
    
    private func createConversation(conversation: ConversationItem) throws -> Int64 {
        var participants: [ParticipantRequest]
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            participants = [ParticipantRequest(userId: conversation.ownerId, role: "")]
        } else {
            participants = ParticipantDAO.shared.participantRequests(conversationId: conversation.conversationId, currentAccountId: currentAccountId)
        }
        let request = ConversationRequest(conversationId: conversation.conversationId, name: nil, category: conversation.category, participants: participants, duration: nil, announcement: nil, randomID: nil)
        let response = try ConversationAPI.createConversation(conversation: request).get()
        ConversationDAO.shared.createConversation(conversation: response, targetStatus: .SUCCESS)
        return response.expireIn
    }
    
    private func sendCallMessage(blazeMessage: BlazeMessage) throws {
        guard let params = blazeMessage.params else {
            return
        }
        guard let categoryString = params.category, let category = MessageCategory(rawValue: categoryString) else {
            return
        }
        guard MixinService.callMessageCoordinator.shouldSendRtcBlazeMessage(with: category) else {
            return
        }
        guard let conversationId = params.conversationId else {
            return
        }
        guard let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId) else {
            return
        }
        try checkConversationExist(conversation: conversation)
        try deliverMessage(blazeMessage: blazeMessage)
    }
    
    private func sendPinMessage(blazeMessage: BlazeMessage) throws {
        guard let params = blazeMessage.params else {
            Logger.general.error(category: "SendPinMessage", message: "No params")
            return
        }
        guard let conversationId = params.conversationId else {
            Logger.general.error(category: "SendPinMessage", message: "No conversation ID")
            return
        }
        guard let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId) else {
            Logger.general.error(category: "SendPinMessage", message: "No conversation")
            return
        }
        try checkConversationExist(conversation: conversation)
        try deliverMessage(blazeMessage: blazeMessage)
    }
    
    private func deliverMessage(blazeMessage: BlazeMessage) throws {
        do {
            try deliver(blazeMessage: blazeMessage)
        } catch MixinAPIResponseError.forbidden {
            #if DEBUG
            print("\(MixinAPIResponseError.forbidden)")
            #endif
        } catch {
            #if DEBUG
            print(error)
            #endif
            throw error
        }
    }
    
}
