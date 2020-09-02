import UIKit
import WebKit
import MixinServices

class SignalLoadingViewController: UIViewController {
    
    class func instance() -> SignalLoadingViewController {
        return R.storyboard.home.signal()!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.write(log: "SignalLoadingView...isPrekeyLoaded:\(AppGroupUserDefaults.Crypto.isPrekeyLoaded)...isSessionSynchronized:\(AppGroupUserDefaults.Crypto.isSessionSynchronized)...isCircleSynchronized:\(AppGroupUserDefaults.User.isCircleSynchronized)")
        let startTime = Date()
        DispatchQueue.global().async {
            try! SignalDatabase.shared.initDatabase()

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
                    WKWebsiteDataStore.default().removeAllCookiesAndLocalStorage()
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
                MixinDatabase.shared.insertOrReplace(objects: circles)

                for circle in circles {
                    syncCircleConversations(circleId: circle.circleId)
                }
                AppGroupUserDefaults.User.isCircleSynchronized = true
                return
            case let .failure(error):
                Thread.sleep(forTimeInterval: 2)
                reporter.report(error: error)
            }
        } while true
    }

    private func syncCircleConversations(circleId: String) {
        var offset: String?
        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return
            }

            switch CircleAPI.circleConversations(circleId: circleId, offset: offset, limit: 500) {
            case let .success(conversations):
                MixinDatabase.shared.insertOrReplace(objects: conversations)
                offset = conversations.last?.createdAt
                if conversations.count < 500 {
                    return
                }
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
        let sessions = SessionDAO.shared.syncGetSessionAddress()
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
                        newSession.append(Session(address: session.address, device: Int(deviceId), record: session.record, timestamp: session.timestamp))
                    }
                }
                SignalDatabase.shared.insertOrReplace(objects: newSession)

                let senderKeys = SenderKeyDAO.shared.syncGetSenderKeys()
                senderKeys.forEach { (key) in
                    if key.senderId.hasSuffix(":1") {
                        let userId = String(key.senderId.prefix(key.senderId.count - 2))
                        if let deviceId = sessionMap[userId] {
                            SenderKeyDAO.shared.insertOrReplace(obj: SenderKey(groupId: key.groupId, senderId: "\(userId):\(deviceId)", record: key.record))
                        }
                    }
                }

                let participants = ParticipantDAO.shared.getAllParticipants()
                let participantSessions: [ParticipantSession] = participants.compactMap {
                    guard let sessionId = userSessionMap[$0.userId] else {
                        return nil
                    }
                    return ParticipantSession(conversationId: $0.conversationId, userId: $0.userId, sessionId: sessionId, sentToServer: nil, createdAt: Date().toUTCString())
                }
                MixinDatabase.shared.insertOrReplace(objects: participantSessions)
                return
            case .failure(.unauthorized):
                return
            case let .failure(error):
                Thread.sleep(forTimeInterval: 2)
                reporter.report(error: error)
            }
        } while true
    }
    
    private func dismiss() {
        AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
    }
    
}
