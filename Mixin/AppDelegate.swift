import UIKit
import Bugsnag
import UserNotifications
import Firebase
import SDWebImage
import YYImage
import GiphyCoreSDK
import PushKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var current: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    var window: UIWindow?
    private var autoCanceleNotification: DispatchWorkItem?
    private var backgroundTaskID = UIBackgroundTaskIdentifier.invalid
    private var backgroundTime: Timer?
    private(set) var voipToken = ""
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if RELEASE
        initBugsnag()
        FirebaseApp.configure()
        #endif
        if SDWebImagePrefetcher.shared.context != nil {
            SDWebImagePrefetcher.shared.context![.animatedImageClass] = YYImage.self
        } else {
            SDWebImagePrefetcher.shared.context = [.animatedImageClass: YYImage.self]
        }
        CommonUserDefault.shared.updateFirstLaunchDateIfNeeded()
        if let account = AccountAPI.shared.account {
            Bugsnag.configuration()?.setUser(account.user_id, withName: account.full_name, andEmail: account.identity_number)
        }
        CommonUserDefault.shared.checkUpdateOrInstallVersion()
        NetworkManager.shared.startListening()
        UNUserNotificationCenter.current().registerNotificationCategory()
        UNUserNotificationCenter.current().delegate = self
        let pkpushRegistry = PKPushRegistry(queue: DispatchQueue.main)
        pkpushRegistry.delegate = self
        pkpushRegistry.desiredPushTypes = [.voIP]
        checkLogin()
        FileManager.default.writeLog(log: "\n-----------------------\nAppDelegate...didFinishLaunching...didLogin:\(AccountAPI.shared.didLogin)...\(Bundle.main.shortVersion)(\(Bundle.main.bundleVersion))")
        checkJailbreak()
        if let key = MixinKeys.giphy {
            GiphyCore.configure(apiKey: key)
        }
        return true
    }

    private func checkJailbreak() {
        guard UIDevice.isJailbreak else {
            return
        }
        Keychain.shared.clearPIN()
    }

    private func initBugsnag() {
        guard let apiKey = MixinKeys.bugsnag else {
            return
        }
        Bugsnag.start(withApiKey: apiKey)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        AudioManager.shared.stop(deactivateAudioSession: true)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        checkServerData()
    }

    private func checkServerData() {
        WebSocketService.shared.checkConnectStatus()

        cancelBackgroundTask()
        self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.cancelBackgroundTask()
        })
        self.backgroundTime = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { (time) in
            self.cancelBackgroundTask()
        }
    }

    private func cancelBackgroundTask() {
        self.backgroundTime?.invalidate()
        self.backgroundTime = nil
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        UNUserNotificationCenter.current().removeAllNotifications()
        WebSocketService.shared.checkConnectStatus()
        cancelBackgroundTask()

        if let conversationId = UIApplication.currentConversationId() {
            SendMessageService.shared.sendReadMessages(conversationId: conversationId)
        }
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        SDImageCache.shared.clearMemory()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        MixinDatabase.shared.close()
        SignalDatabase.shared.close()
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.newData)
    }

    open func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return UrlWindow.checkUrl(url: url)
    }

    func checkLogin() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .black
        if AccountAPI.shared.didLogin {
            window.rootViewController = makeInitialViewController()
            if ContactsManager.shared.authorization == .authorized {
                DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: {
                    PhoneContactAPI.shared.upload(contacts: ContactsManager.shared.contacts)
                })
            }
        } else {
            let vc = LoginMobileNumberViewController()
            let navigationController = LoginNavigationController(rootViewController: vc)
            window.rootViewController = navigationController
        }
        window.makeKeyAndVisible()
        self.window = window
    }
    
}

extension AppDelegate: PKPushRegistryDelegate {

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        voipToken = pushCredentials.token.toHexString()
        if AccountAPI.shared.didLogin {
            AccountAPI.shared.updateSession(deviceToken: "", voip_token: voipToken)
        }
    }


    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        checkServerData()
        FileManager.default.writeLog(log: "\n-----------------------\nAppDelegate...didReceiveIncomingPushWith...")
    }

}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AccountAPI.shared.updateSession(deviceToken: deviceToken.toHexString(), voip_token: "")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if !handerQuickAction(response) {
            dealWithRemoteNotification(response.notification.request.content.userInfo)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        if userInfo["fromWebSocket"] as? Bool ?? false {
            completionHandler([.alert, .sound])
            autoCanceleNotification?.cancel()
            let workItem = DispatchWorkItem(block: {
                guard let workItem = UIApplication.appDelegate().autoCanceleNotification, !workItem.isCancelled else {
                    return
                }
                guard AccountAPI.shared.didLogin else {
                    return
                }
                UNUserNotificationCenter.current().removeNotifications(identifier: NotificationRequestIdentifier.showInApp)
            })
            self.autoCanceleNotification = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: workItem)
        } else {
            completionHandler([])
        }
    }

    fileprivate func dealWithRemoteNotification(_ userInfo: [AnyHashable: Any]?, fromLaunch: Bool = false) {
        guard let userInfo = userInfo, let conversationId = userInfo["conversation_id"] as? String else {
            return
        }
        
        DispatchQueue.global().async {
            guard let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId), conversation.status == ConversationStatus.SUCCESS.rawValue else {
                return
            }
            DispatchQueue.main.async {
                UIApplication.rootNavigationController()?.pushViewController(withBackRoot: ConversationViewController.instance(conversation: conversation))
            }
        }
        UNUserNotificationCenter.current().removeAllNotifications()
    }

    @available(iOS 10.0, *)
    func handerQuickAction(_ response: UNNotificationResponse) -> Bool {
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        let actionIdentifier = response.actionIdentifier
        let inputText = (response as? UNTextInputNotificationResponse)?.userText
        let userInfo = response.notification.request.content.userInfo
        return handerQuickAction(categoryIdentifier: categoryIdentifier, actionIdentifier: actionIdentifier, inputText: inputText, userInfo: userInfo)
    }

    @discardableResult
    func handerQuickAction(categoryIdentifier: String, actionIdentifier: String, inputText: String?, userInfo: [AnyHashable : Any]) -> Bool {
        guard categoryIdentifier == NotificationCategoryIdentifier.message, AccountAPI.shared.didLogin else {
            return false
        }

        guard let conversationId = userInfo["conversation_id"] as? String, let conversationCategory = userInfo["conversation_category"] as? String else {
            return false
        }

        switch actionIdentifier {
        case NotificationActionIdentifier.reply:
            guard let text = inputText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return false
            }
            var ownerUser: UserItem?
            if let userId = userInfo["user_id"] as? String, let userFullName = userInfo["userFullName"] as? String, let userAvatarUrl = userInfo["userAvatarUrl"] as? String, let userIdentityNumber = userInfo["userIdentityNumber"] as? String {
                ownerUser = UserItem.createUser(userId: userId, fullName: userFullName, identityNumber: userIdentityNumber, avatarUrl: userAvatarUrl, appId: userInfo["userAppId"] as? String)
            }
            var newMsg = Message.createMessage(category: MessageCategory.SIGNAL_TEXT.rawValue, conversationId: conversationId, createdAt: Date().toUTCString(), userId: AccountAPI.shared.accountUserId)
            newMsg.content = text
            DispatchQueue.global().async {
                SendMessageService.shared.sendMessage(message: newMsg, ownerUser: ownerUser, isGroupMessage: conversationCategory == ConversationCategory.GROUP.rawValue)
            }
        default:
            return false
        }
        return true
    }
}

