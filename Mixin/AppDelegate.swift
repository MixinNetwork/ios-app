import UIKit
import Bugsnag
import UserNotifications
import Firebase
import SDWebImage

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var current: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    var window: UIWindow?
    private var autoCanceleNotification: DispatchWorkItem?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        #if RELEASE
        initBugsnag()
        FirebaseApp.configure()
        #endif
        AccountUserDefault.shared.upgrade()
        if let account = AccountAPI.shared.account {
            Bugsnag.configuration()?.setUser(account.user_id, withName: account.full_name, andEmail: account.identity_number)
        }
        CommonUserDefault.shared.checkUpdateOrInstallVersion()
        NetworkManager.shared.startListening()
        UNUserNotificationCenter.current().registerNotificationCategory()
        UNUserNotificationCenter.current().delegate = self
        checkLogin()
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        return true
    }

    private func initBugsnag() {
        guard let apiKey = MixinKeys.bugsnag else {
            return
        }
        Bugsnag.start(withApiKey: apiKey)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        MXNAudioPlayer.shared().stop(withAudioSessionDeactivated: true)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        UNUserNotificationCenter.current().removeAllNotifications()
        WebSocketService.shared.checkConnectStatus()
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        SDImageCache.shared().clearMemory()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        MixinDatabase.shared.close()
        SignalDatabase.shared.close()
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.newData)
    }

    open func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return UrlWindow.checkUrl(url: url)
    }

    func checkLogin() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .black
        if AccountAPI.shared.didLogin {
            window.rootViewController = HomeViewController.instance()
            if ContactsManager.shared.authorization == .authorized {
                DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: {
                    PhoneContactAPI.shared.upload(contacts: ContactsManager.shared.contacts)
                })
            }
        } else {
            window.rootViewController = LoginNavigationController.instance()
        }
        window.makeKeyAndVisible()
        self.window = window
    }
    
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AccountAPI.shared.updateSession(deviceToken: deviceToken.toHexString())
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
                UNUserNotificationCenter.current().removeNotifications(identifier: NotificationIdentifier.showInAppNotification.rawValue)
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
        return handerQuickAction(categoryIdentifier: categoryIdentifier, handleActionIdentifier: actionIdentifier, inputText: inputText, userInfo: userInfo)
    }

    @discardableResult
    func handerQuickAction(categoryIdentifier: String, handleActionIdentifier: String, inputText: String?, userInfo: [AnyHashable : Any]) -> Bool {
        guard categoryIdentifier == NotificationIdentifier.actionCategory.rawValue, AccountAPI.shared.didLogin else {
            return false
        }

        guard let conversationId = userInfo["conversation_id"] as? String, let conversationCategory = userInfo["conversation_category"] as? String else {
            return false
        }

        switch handleActionIdentifier {
        case NotificationIdentifier.replyAction.rawValue:
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

