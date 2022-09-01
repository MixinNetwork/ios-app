import UIKit
import WebKit
import MixinServices

class SignalLoadingViewController: UIViewController {
    
    private var isUsernameJustInitialized = false
    
    private var newUserInitialBots: [InitializeBotJob.Bot] {
        guard let account = LoginManager.shared.account else {
            return []
        }
        if ["+971", "+91"].contains(where: account.phone.hasPrefix) {
            return [
                InitializeBotJob.Bot(userId: "68ef7899-3e81-4b3d-8124-83ae652def89", fullname: "Mixin Bots"),
                InitializeBotJob.Bot(userId: "96c1460b-c7c4-480a-a342-acaa73995a37", fullname: "Mixin Data"),
            ]
        } else if ["+81"].contains(where: account.phone.hasPrefix) {
            return [InitializeBotJob.Bot(userId: "482d17d1-9eb3-4177-ac37-08b24277732b", fullname: "Mixinコミュニティ")]
        } else {
            return []
        }
    }
    
    private var allUsersInitialBots: [InitializeBotJob.Bot] {
        [InitializeBotJob.Bot(userId: "773e5e77-4107-45c2-b648-8fc722ed77f5", fullname: "Team Mixin")]
    }
    
    class func instance(isUsernameJustInitialized: Bool) -> SignalLoadingViewController {
        let controller = R.storyboard.home.signal()!
        controller.isUsernameJustInitialized = isUsernameJustInitialized
        return controller
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.general.info(category: "SignalLoading", message: "isPrekeyLoaded:\(AppGroupUserDefaults.Crypto.isPrekeyLoaded), isSessionSynchronized:\(AppGroupUserDefaults.Crypto.isSessionSynchronized), isCircleSynchronized:\(AppGroupUserDefaults.User.isCircleSynchronized)")
        let startTime = Date()
        DispatchQueue.global().async {
            SignalDatabase.reloadCurrent()

            self.syncSignalKeys()
            self.syncSession()
            self.syncCircles()

            DispatchQueue.main.async {
                let time = Date().timeIntervalSince(startTime)
                if time < 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + (2 - time), execute: {
                        self.dismiss()
                    })
                } else {
                    self.dismiss()
                }
            }
        }
    }

    private func syncSignalKeys() {
        guard !AppGroupUserDefaults.Crypto.isPrekeyLoaded else {
            return
        }

        IdentityDAO.shared.saveLocalIdentity()

        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return
            }
            switch SignalKeyAPI.pushSignalKeys(key: try! PreKeyUtil.generateKeys()) {
            case .success:
                AppGroupUserDefaults.Crypto.isPrekeyLoaded = true
                DispatchQueue.main.async {
                    WKWebsiteDataStore.default().removeAuthenticationRelatedData()
                }
                return
            case .failure(.unauthorized):
                return
            case let .failure(error):
                Thread.sleep(forTimeInterval: 2)
                reporter.report(error: error)
            }
        } while true
    }
    
    private func syncSession() {
        guard !AppGroupUserDefaults.Crypto.isSessionSynchronized else {
            return
        }

        AppGroupUserDefaults.Account.extensionSession = nil
        JobDAO.shared.clearSessionJob()
        let sessions = SessionDAO.shared.getSessionAddress()
        let userIds = sessions.compactMap { $0.address }

        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return
            }

            switch UserAPI.fetchSessions(userIds: userIds) {
            case let .success(remoteSessions):
                defer {
                    AppGroupUserDefaults.Crypto.isSessionSynchronized = true
                }
                var sessionMap = [String: Int32]()
                var userSessionMap = [String: String]()
                remoteSessions.forEach { (session) in
                    if session.platform == "Android" || session.platform == "iOS" {
                        sessionMap[session.userId] = SignalProtocol.convertSessionIdToDeviceId(session.sessionId)
                        userSessionMap[session.userId] = session.sessionId
                    }
                }

                guard sessionMap.count > 0 else {
                    return
                }

                var newSession = [Session]()
                sessions.forEach { (session) in
                    if let deviceId = sessionMap[session.address] {
                        newSession.append(Session(address: session.address, device: deviceId, record: session.record, timestamp: session.timestamp))
                    }
                }
                SignalDatabase.current.save(newSession)

                let senderKeys = SenderKeyDAO.shared.getAllSenderKeys()
                senderKeys.forEach { (key) in
                    if key.senderId.hasSuffix(":1") {
                        let userId = String(key.senderId.prefix(key.senderId.count - 2))
                        if let deviceId = sessionMap[userId] {
                            let key = SenderKey(groupId: key.groupId, senderId: "\(userId):\(deviceId)", record: key.record)
                            SignalDatabase.current.save(key)
                        }
                    }
                }

                let participants = ParticipantDAO.shared.getAllParticipants()
                let participantSessions: [ParticipantSession] = participants.compactMap {
                    guard let sessionId = userSessionMap[$0.userId] else {
                        return nil
                    }
                    return ParticipantSession(conversationId: $0.conversationId,
                                              userId: $0.userId,
                                              sessionId: sessionId,
                                              sentToServer: nil,
                                              createdAt: Date().toUTCString(),
                                              publicKey: nil)
                }
                UserDatabase.current.save(participantSessions)
                return
            case .failure(.unauthorized):
                return
            case let .failure(error):
                Thread.sleep(forTimeInterval: 2)
                reporter.report(error: error)
            }
        } while true
    }
    
    private func syncCircles() {
        guard !AppGroupUserDefaults.User.isCircleSynchronized else {
            return
        }
        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return
            }
            switch CircleAPI.circles() {
            case let .success(response):
                let circles = response.map { Circle(circleId: $0.circleId, name: $0.name, createdAt: $0.createdAt) }
                UserDatabase.current.save(circles)
                
                var allConversationIds: Set<String> = []
                for circle in circles {
                    let conversationIds = syncCircleConversations(circleId: circle.circleId)
                    allConversationIds.formUnion(conversationIds)
                }
                allConversationIds.forEach(syncConversation(conversationId:))
                
                AppGroupUserDefaults.User.isCircleSynchronized = true
                return
            case let .failure(error):
                Thread.sleep(forTimeInterval: 2)
                reporter.report(error: error)
            }
        } while true
    }
    
    // Returns conversations' id
    private func syncCircleConversations(circleId: String) -> Set<String> {
        var offset: String?
        var conversationIds: Set<String> = []
        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return []
            }
            switch CircleAPI.circleConversations(circleId: circleId, offset: offset, limit: 500) {
            case let .success(conversations):
                UserDatabase.current.save(conversations)
                offset = conversations.last?.createdAt
                conversationIds.formUnion(conversations.map(\.conversationId))
                if conversations.count < 500 {
                    return conversationIds
                }
            case .failure(.notFound):
                return []
            case let .failure(error) where error.worthRetrying:
                Thread.sleep(forTimeInterval: 2)
            case let .failure(error):
                reporter.report(error: error)
                return []
            }
        } while true
    }
    
    private func syncConversation(conversationId: String) {
        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return
            }
            guard !ConversationDAO.shared.isExist(conversationId: conversationId) else {
                return
            }
            switch ConversationAPI.getConversation(conversationId: conversationId) {
            case let .success(response):
                ConversationDAO.shared.createConversation(conversation: response, targetStatus: .SUCCESS)
                return
            case .failure(.notFound):
                return
            case let .failure(error) where error.worthRetrying:
                Thread.sleep(forTimeInterval: 2)
            case let .failure(error):
                reporter.report(error: error)
                return
            }
        } while true
    }
    
    private func dismiss() {
        let vc = makeInitialViewController(isUsernameJustInitialized: isUsernameJustInitialized)
        AppDelegate.current.mainWindow.rootViewController = vc
        if vc is HomeContainerViewController {
            initialize(bots: allUsersInitialBots)
            if isUsernameJustInitialized {
                initialize(bots: newUserInitialBots)
            }
        }
    }
    
    private func initialize(bots: [InitializeBotJob.Bot]) {
        for bot in bots {
            let job = InitializeBotJob(bot: bot)
            ConcurrentJobQueue.shared.addJob(job: job)
        }
    }
    
}
