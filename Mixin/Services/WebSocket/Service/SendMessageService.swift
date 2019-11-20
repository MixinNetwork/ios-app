import Foundation
import WCDBSwift

class SendMessageService: MixinService {

    static let shared = SendMessageService()
    static let recallableSuffices = ["_TEXT", "_STICKER", "_CONTACT", "_IMAGE", "_DATA", "_AUDIO", "_VIDEO", "_LIVE"]
    
    private let dispatchQueue = DispatchQueue(label: "one.mixin.messenger.queue.send.messages")
    private let httpDispatchQueue = DispatchQueue(label: "one.mixin.messenger.queue.send.http.messages")
    private let saveDispatchQueue = DispatchQueue(label: "one.mixin.messenger.queue.send")
    private var httpProcessing = false

    func restoreJobs() {
        DispatchQueue.global().async {
            let messages = MessageDAO.shared.getPendingMessages()
            for message in messages {
                guard message.shouldUpload() else {
                    continue
                }
                if message.category.hasSuffix("_IMAGE") {
                    UploaderQueue.shared.addJob(job: ImageUploadJob(message: message))
                } else if message.category.hasSuffix("_DATA") {
                    UploaderQueue.shared.addJob(job: FileUploadJob(message: message))
                } else if message.category.hasSuffix("_VIDEO") {
                    UploaderQueue.shared.addJob(job: VideoUploadJob(message: message))
                } else if message.category.hasSuffix("_AUDIO") {
                    UploaderQueue.shared.addJob(job: AudioUploadJob(message: message))
                }
            }

            SendMessageService.shared.processMessages()
        }
    }

    func sendMessage(message: Message, ownerUser: UserItem?, isGroupMessage: Bool) {
        guard let account = AccountAPI.shared.account else {
            return
        }

        var msg = message
        msg.userId = account.user_id
        msg.status = MessageStatus.SENDING.rawValue

        var isSignalMessage = isGroupMessage
        if !isGroupMessage {
            isSignalMessage = !(ownerUser?.isBot ?? true)
        }

        if msg.category.hasSuffix("_TEXT") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_TEXT.rawValue :  MessageCategory.PLAIN_TEXT.rawValue
        } else if msg.category.hasSuffix("_IMAGE") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_IMAGE.rawValue :  MessageCategory.PLAIN_IMAGE.rawValue
        } else if msg.category.hasSuffix("_VIDEO") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_VIDEO.rawValue :  MessageCategory.PLAIN_VIDEO.rawValue
        } else if msg.category.hasSuffix("_DATA") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_DATA.rawValue :  MessageCategory.PLAIN_DATA.rawValue
        } else if msg.category.hasSuffix("_STICKER") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_STICKER.rawValue :  MessageCategory.PLAIN_STICKER.rawValue
        } else if msg.category.hasSuffix("_CONTACT") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_CONTACT.rawValue :  MessageCategory.PLAIN_CONTACT.rawValue
        } else if msg.category.hasSuffix("_AUDIO") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_AUDIO.rawValue :  MessageCategory.PLAIN_AUDIO.rawValue
        } else if msg.category.hasSuffix("_LIVE") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_LIVE.rawValue :  MessageCategory.PLAIN_LIVE.rawValue
        }

        if msg.conversationId.isEmpty || !ConversationDAO.shared.isExist(conversationId: msg.conversationId) {
            guard let user = ownerUser else {
                return
            }
            let conversationId = ConversationDAO.shared.makeConversationId(userId: account.user_id, ownerUserId: user.userId)
            msg.conversationId = conversationId

            let createdAt = Date().toUTCString()
            let participants = [ParticipantResponse(userId: user.userId, role: ParticipantRole.OWNER.rawValue, createdAt: createdAt), ParticipantResponse(userId: account.user_id, role: "", createdAt: createdAt)]
            let response = ConversationResponse(conversationId: conversationId, name: "", category: ConversationCategory.CONTACT.rawValue, iconUrl: user.avatarUrl, announcement: "", createdAt: Date().toUTCString(), participants: participants, participantSessions: nil, codeUrl: "", creatorId: user.userId, muteUntil: "")
            ConversationDAO.shared.createConversation(conversation: response, targetStatus: .START)
        }
        if !message.category.hasPrefix("WEBRTC_") {
            MessageDAO.shared.insertMessage(message: msg, messageSource: "")
        }
        if msg.category.hasSuffix("_TEXT") || msg.category.hasSuffix("_STICKER") || message.category.hasSuffix("_CONTACT") || message.category.hasSuffix("_LIVE") {
            SendMessageService.shared.sendMessage(message: msg, data: message.content)
        } else if msg.category.hasSuffix("_IMAGE") {
            UploaderQueue.shared.addJob(job: ImageUploadJob(message: msg))
        } else if msg.category.hasSuffix("_VIDEO") {
            UploaderQueue.shared.addJob(job: VideoUploadJob(message: msg))
        } else if msg.category.hasSuffix("_DATA") {
            UploaderQueue.shared.addJob(job: FileUploadJob(message: msg))
        } else if msg.category.hasSuffix("_AUDIO") {
            UploaderQueue.shared.addJob(job: AudioUploadJob(message: msg))
        } else if message.category.hasPrefix("WEBRTC_"), let recipient = ownerUser {
            SendMessageService.shared.sendWebRTCMessage(message: message, recipientId: recipient.userId)
        }
    }

    func recallMessage(messageId: String, category: String, mediaUrl: String?, conversationId: String, status: String) {
        guard SendMessageService.recallableSuffices.contains(where: category.hasSuffix) else {
            return
        }
        
        saveDispatchQueue.async {
            let blazeMessage = BlazeMessage(recallMessageId: messageId, conversationId: conversationId)
            var jobs = [Job]()
            jobs.append(Job(jobId: UUID().uuidString.lowercased(), action: JobAction.SEND_MESSAGE, conversationId: conversationId, blazeMessage: blazeMessage))

            ReceiveMessageService.shared.stopRecallMessage(messageId: messageId, category: category, conversationId: conversationId, mediaUrl: mediaUrl)

            let quoteMessageIds = MixinDatabase.shared.getStringValues(column: Message.Properties.messageId.asColumnResult(), tableName: Message.tableName, condition: Message.Properties.conversationId == conversationId && Message.Properties.quoteMessageId == messageId)

            MixinDatabase.shared.transaction { (database) in
                try database.insertOrReplace(objects: jobs, intoTable: Job.tableName)
                try MessageDAO.shared.recallMessage(database: database, messageId: messageId, conversationId: conversationId, category: category, status: status, quoteMessageIds: quoteMessageIds)
            }
            SendMessageService.shared.processMessages()
        }
    }

    func sendMessage(message: Message, data: String?) {
        let content = message.category == MessageCategory.PLAIN_TEXT.rawValue ? data?.base64Encoded() : data
        saveDispatchQueue.async {
            MixinDatabase.shared.insertOrReplace(objects: [Job(message: message, data: content)])
            SendMessageService.shared.processMessages()
        }
    }

    func sendWebRTCMessage(message: Message, recipientId: String) {
        saveDispatchQueue.async {
            MixinDatabase.shared.insertOrReplace(objects: [Job(webRTCMessage: message, recipientId: recipientId)])
            SendMessageService.shared.processMessages()
        }
    }

    func sendMessage(action: JobAction) {
        saveDispatchQueue.async {
            let job = Job(jobId: UUID().uuidString.lowercased(), action: action)
            MixinDatabase.shared.insertOrReplace(objects: [job])
            SendMessageService.shared.processMessages()
        }
    }

    func sendMessage(conversationId: String, userId: String, sessionId: String?, action: JobAction) {
        saveDispatchQueue.async {
            let job = Job(jobId: UUID().uuidString.lowercased(), action: action, userId: userId, conversationId: conversationId, sessionId: sessionId)
            MixinDatabase.shared.insertOrReplace(objects: [job])
            SendMessageService.shared.processMessages()
        }
    }

    func sendMessage(conversationId: String, userId: String, blazeMessage: BlazeMessage, action: JobAction) {
        saveDispatchQueue.async {
            let job = Job(jobId: blazeMessage.id, action: action, userId: userId, conversationId: conversationId, blazeMessage: blazeMessage)
            MixinDatabase.shared.insertOrReplace(objects: [job])
            SendMessageService.shared.processMessages()
        }
    }

    func resendMessages(conversationId: String, userId: String, sessionId: String, messageIds: [String]) {
        var jobs = [Job]()
        var resendMessages = [ResendSessionMessage]()
        for messageId in messageIds {
            guard !ResendSessionMessageDAO.shared.isExist(messageId: messageId, userId: userId, sessionId: sessionId) else {
                continue
            }

            if let message = MessageDAO.shared.getMessage(messageId: messageId), message.category != MessageCategory.MESSAGE_RECALL.rawValue {
                let param = BlazeMessageParam(conversationId: conversationId, recipientId: userId, status: MessageStatus.SENT.rawValue, messageId: messageId, sessionId: sessionId)
                let blazeMessage = BlazeMessage(params: param, action: BlazeMessageAction.createMessage.rawValue)
                jobs.append(Job(jobId: blazeMessage.id, action: .RESEND_MESSAGE, userId: userId, conversationId: conversationId, resendMessageId: UUID().uuidString.lowercased(), sessionId: sessionId, blazeMessage: blazeMessage))
                resendMessages.append(ResendSessionMessage(messageId: messageId, userId: userId, sessionId: sessionId, status: 1))
            } else {
                resendMessages.append(ResendSessionMessage(messageId: messageId, userId: userId, sessionId: sessionId, status: 0))
            }
        }

        saveDispatchQueue.async {
            MixinDatabase.shared.transaction(callback: { (database) in
                try database.insertOrReplace(objects: jobs, intoTable: Job.tableName)
                try database.insertOrReplace(objects: resendMessages, intoTable: ResendSessionMessage.tableName)
            })
            SendMessageService.shared.processMessages()
        }
    }

    func sendReadMessages(conversationId: String, force: Bool = false) {
        DispatchQueue.main.async {
            guard force || UIApplication.shared.applicationState == .active else {
                return
            }
            SendMessageService.shared.saveDispatchQueue.async {
                let messageIds = MixinDatabase.shared.getStringValues(column: Message.Properties.messageId.asColumnResult(), tableName: Message.tableName, condition: Message.Properties.conversationId == conversationId && Message.Properties.status == MessageStatus.DELIVERED.rawValue && Message.Properties.userId != AccountAPI.shared.accountUserId, orderBy: [Message.Properties.createdAt.asOrder(by: .ascending)])
                var position = 0
                let pageCount = AppGroupUserDefaults.Account.isDesktopLoggedIn ? 1000 : 2000
                while messageIds.count > 0 && position < messageIds.count {
                    let nextPosition = position + pageCount > messageIds.count ? messageIds.count : position + pageCount
                    let ids = Array(messageIds[position..<nextPosition])
                    var jobs = [Job]()

                    guard let lastMessageId = ids.last else {
                        return
                    }
                    let lastRowID = MixinDatabase.shared.getRowId(tableName: Message.tableName, condition: Message.Properties.messageId == lastMessageId)
                    if ids.count == 1 {
                        let messageId = ids[0]
                        let blazeMessage = BlazeMessage(ackBlazeMessage: messageId, status: MessageStatus.READ.rawValue)
                        jobs.append(Job(jobId: blazeMessage.id, action: .SEND_ACK_MESSAGE, blazeMessage: blazeMessage))

                        if AppGroupUserDefaults.Account.isDesktopLoggedIn {
                            jobs.append(Job(sessionRead: conversationId, messageId: messageId))
                        }
                    } else {
                        for i in stride(from: 0, to: ids.count, by: 100) {
                            let by = i + 100 > ids.count ? ids.count : i + 100
                            let messages: [TransferMessage] = ids[i..<by].map { TransferMessage(messageId: $0, status: MessageStatus.READ.rawValue) }
                            let blazeMessage = BlazeMessage(params: BlazeMessageParam(messages: messages), action: BlazeMessageAction.acknowledgeMessageReceipts.rawValue)
                            jobs.append(Job(jobId: blazeMessage.id, action: .SEND_ACK_MESSAGES, blazeMessage: blazeMessage))

                            if let sessionId = AppGroupUserDefaults.Account.extensionSession {
                                let blazeMessage = BlazeMessage(params: BlazeMessageParam(sessionId: sessionId, conversationId: conversationId, ackMessages: messages), action: BlazeMessageAction.createMessage.rawValue)
                                jobs.append(Job(jobId: blazeMessage.id, action: .SEND_SESSION_MESSAGES, blazeMessage: blazeMessage))
                            }
                        }
                    }

                    MixinDatabase.shared.transaction { (database) in
                        try database.insert(objects: jobs, intoTable: Job.tableName)
                        try database.prepareUpdateSQL(sql: "UPDATE messages SET status = '\(MessageStatus.READ.rawValue)' WHERE conversation_id = ? AND status = ? AND user_id != ? AND ROWID <= ?").execute(with: [conversationId, MessageStatus.DELIVERED.rawValue, AccountAPI.shared.accountUserId, lastRowID])
                        try MessageDAO.shared.updateUnseenMessageCount(database: database, conversationId: conversationId)
                    }

                    position = nextPosition
                    if nextPosition < messageIds.count {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                }
                ConversationDAO.shared.showBadgeNumber()
                NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange)
                SendMessageService.shared.processMessages()
            }
        }
    }

    func sendAckMessage(messageId: String, status: MessageStatus) {
        saveDispatchQueue.async {
            let blazeMessage = BlazeMessage(ackBlazeMessage: messageId, status: status.rawValue)
            let action: JobAction = status == .DELIVERED ? .SEND_DELIVERED_ACK_MESSAGE : .SEND_ACK_MESSAGE
            let job = Job(jobId: blazeMessage.id, action: action, blazeMessage: blazeMessage)
            MixinDatabase.shared.insertOrReplace(objects: [job])
            SendMessageService.shared.processMessages()
        }
    }

    func processMessages() {
        processHttpMessages()
        processWebSocketMessages()
    }

    func processHttpMessages() {
        guard !httpProcessing else {
            return
        }
        httpProcessing = true

        httpDispatchQueue.async {
            defer {
                SendMessageService.shared.httpProcessing = false
            }
            repeat {
                guard AccountAPI.shared.didLogin else {
                    return
                }

                let jobs = JobDAO.shared.nextBatchHttpJobs(limit: 100)
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
            switch MessageAPI.shared.acknowledgements(ackMessages: ackMessages) {
            case .success:
                return true
            case let .failure(error):
                guard error.code != 401 else {
                    return false
                }
                guard error.code != 403 else {
                    return true
                }
                SendMessageService.shared.checkNetworkAndWebSocket()
                Thread.sleep(forTimeInterval: 2)
            }
        } while true
    }

    func processWebSocketMessages() {
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
                guard AccountAPI.shared.didLogin else {
                    return
                }
                guard let job = JobDAO.shared.nextJob() else {
                    return
                }

                if job.action == JobAction.SEND_SESSION_MESSAGE.rawValue {
                    guard let sessionId = AppGroupUserDefaults.Account.extensionSession else {
                        JobDAO.shared.removeJob(jobId: job.jobId)
                        continue
                    }
                    let jobs = JobDAO.shared.nextBatchSessionJobs(limit: 100)
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
                        Reporter.report(error: MixinServicesError.duplicatedJob)
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
        } catch {
            if let err = error as? APIError {
                if err.code == 403 {
                    return true
                } else if err.code == 401 {
                    return false
                } else if err.isClientError {
                    Thread.sleep(forTimeInterval: 2)
                } else {
                    Reporter.report(error: error)
                }
            }

            while AccountAPI.shared.didLogin && (!NetworkManager.shared.isReachable || !WebSocketService.shared.isConnected) {
                Thread.sleep(forTimeInterval: 2)
            }
            return false
        }
    }

    private func handlerJob(job: Job) -> Bool {
        repeat {
            guard AccountAPI.shared.didLogin else {
                return false
            }

            do {
                switch job.action {
                case JobAction.SEND_MESSAGE.rawValue:
                    try ReceiveMessageService.shared.messageDispatchQueue.sync {
                        let blazeMessage = job.toBlazeMessage()
                        if blazeMessage.action == BlazeMessageAction.createCall.rawValue {
                            try SendMessageService.shared.sendCallMessage(blazeMessage: blazeMessage)
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
                        return refreshParticipantSession(conversationId: job.conversationId!, userId: job.userId!, retry: true)
                    }
                case JobAction.RESEND_KEY.rawValue:
                    try ReceiveMessageService.shared.messageDispatchQueue.sync {
                        guard let conversationId = job.conversationId, let recipientId = job.userId, let sessionId = job.sessionId else {
                            return
                        }

                        let result = try sendSenderKey(conversationId: conversationId, recipientId: recipientId, sessionId: sessionId)
                        if !result {
                            FileManager.default.writeLog(conversationId: conversationId, log: "[ResendSenderKey]...recipientId:\(recipientId)...No any group signal key from server")
                            sendNoKeyMessage(conversationId: conversationId, recipientId: recipientId)
                        }
                    }
                case JobAction.REQUEST_RESEND_KEY.rawValue:
                    ReceiveMessageService.shared.messageDispatchQueue.sync {
                        let blazeMessage = job.toBlazeMessage()
                        deliverNoThrow(blazeMessage: blazeMessage)
                        FileManager.default.writeLog(conversationId: job.conversationId!, log: "[SendMessageService][REQUEST_RESEND_KEY]...messageId:\(blazeMessage.params?.messageId ?? "")")
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

                if let err = error as? APIError, err.status == NSURLErrorTimedOut {

                } else {
                    var blazeMessage = ""
                    if let bm = job.blazeMessage {
                        blazeMessage = String(data: bm, encoding: .utf8) ?? ""
                    }

                    #if DEBUG
                    print("======SendMessageService...handlerJob...\(error)...JobAction:\(job.action)....currentUserId:\(AccountAPI.shared.accountUserId)...blazeMessage:\(blazeMessage)")
                    #endif
                    FileManager.default.writeLog(log: "[SendMessageService][HandlerJob]...JobAction:\(job.action)...conversationId:\(job.conversationId ?? "")...blazeMessage:\(blazeMessage)...\(error)")
                    var userInfo = [String: Any]()
                    userInfo["errorCode"] = error.errorCode
                    userInfo["errorDescription"] = error.localizedDescription
                    userInfo["JobAction"] = job.action
                    userInfo["blazeMessage"] = blazeMessage
                    if let err = error as? SignalError {
                        userInfo["signalErrorCode"] = err.rawValue
                        if IdentityDAO.shared.getLocalIdentity() == nil {
                            userInfo["signalError"] = "local identity nil"
                            userInfo["identityCount"] = "\(IdentityDAO.shared.getCount())"
                            Reporter.report(error: MixinServicesError.sendMessage(userInfo))
                            AccountAPI.shared.logout(from: "SendMessengerError")
                            return false
                        }
                    }
                    Reporter.report(error: MixinServicesError.sendMessage(userInfo))
                }

                if let err = error as? APIError, err.code == 10002 {
                    return true
                }
            }
        } while true
    }
}

extension SendMessageService {


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

        FileManager.default.writeLog(conversationId: message.conversationId, log: "[SendMessageService][ResendMessage]...messageId:\(messageId)...resendMessageId:\(resendMessageId)...resendUserId:\(recipientId)")
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
            UIApplication.traceError(code: ReportErrorCode.sendMessengerError, userInfo: userInfo)
            return
        }

        if conversation.category == ConversationCategory.GROUP.rawValue,  message.category.hasSuffix("_TEXT"), let text = message.content, text.hasPrefix("@700"), let botNumberRange = text.range(of: #"^@700\d* "#, options: .regularExpression) {
            let identityNumber = text[botNumberRange].dropFirstAndLast()
            if let recipientId = ParticipantDAO.shared.getParticipantId(conversationId: conversation.conversationId, identityNumber: identityNumber), !recipientId.isEmpty {
                message.category = MessageCategory.PLAIN_TEXT.rawValue
                blazeMessage.params?.recipientId = recipientId
                blazeMessage.params?.data = nil
            }
        }

        if message.category == MessageCategory.MESSAGE_RECALL.rawValue {
            blazeMessage.params?.messageId = UUID().uuidString.lowercased()
        } else {
            blazeMessage.params?.category = message.category
            blazeMessage.params?.quoteMessageId = message.quoteMessageId
        }

        if message.category.hasPrefix("PLAIN_") || message.category == MessageCategory.MESSAGE_RECALL.rawValue {
            try checkConversationExist(conversation: conversation)
            if blazeMessage.params?.data == nil {
                if message.category == MessageCategory.PLAIN_TEXT.rawValue {
                    blazeMessage.params?.data = message.content?.base64Encoded()
                } else {
                    blazeMessage.params?.data = message.content
                }
            }
        } else {
            if !SignalProtocol.shared.isExistSenderKey(groupId: message.conversationId, senderId: message.userId) {
                if conversation.isGroup() {
                    syncConversation(conversationId: message.conversationId)
                } else {
                    try createConversation(conversation: conversation)
                }
            }
            try checkSessionSenderKey(conversationId: message.conversationId)

            let content = blazeMessage.params?.data ?? message.content ?? ""
            blazeMessage.params?.data = try SignalProtocol.shared.encryptGroupMessageData(conversationId: message.conversationId, senderId: message.userId, content: content)
        }
        try deliverMessage(blazeMessage: blazeMessage)
        FileManager.default.writeLog(conversationId: message.conversationId, log: "[SendMessageService][SendMessage][\(message.category)]...messageId:\(messageId)...messageStatus:\(message.status)")
    }

    private func checkConversationExist(conversation: ConversationItem) throws {
        guard conversation.status == ConversationStatus.START.rawValue else {
            return
        }

        try createConversation(conversation: conversation)
    }

    private func createConversation(conversation: ConversationItem) throws {
        var participants: [ParticipantRequest]
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            participants = [ParticipantRequest(userId: conversation.ownerId, role: "")]
        } else {
            participants = ParticipantDAO.shared.participantRequests(conversationId: conversation.conversationId, currentAccountId: currentAccountId)
        }
        let request = ConversationRequest(conversationId: conversation.conversationId, name: nil, category: conversation.category, participants: participants, duration: nil, announcement: nil)
        switch ConversationAPI.shared.createConversation(conversation: request) {
        case let .success(response):
            ConversationDAO.shared.createConversation(conversation: response, targetStatus: .SUCCESS)
        case let .failure(error):
            if error.code == 10002 {
                MessageDAO.shared.clearChat(conversationId: conversation.conversationId, autoNotification: false)
            }
            throw error
        }
    }

    private func sendCallMessage(blazeMessage: BlazeMessage) throws {
        let onlySendWhenThereIsAnActiveCall = blazeMessage.params?.category == MessageCategory.WEBRTC_AUDIO_OFFER.rawValue
            || blazeMessage.params?.category == MessageCategory.WEBRTC_AUDIO_ANSWER.rawValue
            || blazeMessage.params?.category == MessageCategory.WEBRTC_ICE_CANDIDATE.rawValue
        guard CallManager.shared.call != nil || !onlySendWhenThereIsAnActiveCall else {
            return
        }
        guard let conversationId = blazeMessage.params?.conversationId else {
            return
        }
        guard let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId) else {
            return
        }
        try checkConversationExist(conversation: conversation)
        try deliverMessage(blazeMessage: blazeMessage)
    }

    private func deliverMessage(blazeMessage: BlazeMessage) throws {
        do {
            try deliver(blazeMessage: blazeMessage)
        } catch {
            #if DEBUG
            print(error)
            #endif
            if let err = error as? APIError, err.code == 403 {
                return
            }
            throw error
        }
    }

}
