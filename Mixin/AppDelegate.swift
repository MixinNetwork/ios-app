import UIKit
import UserNotifications
import SDWebImage
import YYImage
import PushKit
import AVFoundation
import WebKit
import MixinServices

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static var current: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    let window = UIWindow(frame: UIScreen.main.bounds)
    
    private(set) var voipToken = ""
    
    private var autoCanceleNotification: DispatchWorkItem?
    private var backgroundTaskID = UIBackgroundTaskIdentifier.invalid
    private var backgroundTime: Timer?
    private var pendingShortcutItem: UIApplicationShortcutItem?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppGroupUserDefaults.migrateIfNeeded()
        Reporter.configure(bugsnagApiKey: MixinKeys.bugsnag)
        updateSharedImageCacheConfig()
        NetworkManager.shared.startListening()
        UNUserNotificationCenter.current().setNotificationCategories([.message])
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        let pkpushRegistry = PKPushRegistry(queue: DispatchQueue.main)
        pkpushRegistry.delegate = self
        pkpushRegistry.desiredPushTypes = [.voIP]
        checkLogin()
        checkJailbreak()
        configAnalytics()
        pendingShortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem
        NotificationCenter.default.addObserver(self, selector: #selector(updateApplicationIconBadgeNumber), name: MixinService.messageReadStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cleanForLogout), name: LoginManager.didLogoutNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleClockSkew), name: MixinService.clockSkewDetectedNotification, object: nil)
        NotificationCenter.default.addObserver(SendMessageService.shared, selector: #selector(SendMessageService.uploadAnyPendingMessages), name: WebSocketService.pendingMessageUploadingDidBecomeAvailableNotification, object: nil)
        Logger.write(log: "\n-----------------------\nAppDelegate...didFinishLaunching...isProtectedDataAvailable:\(UIApplication.shared.isProtectedDataAvailable)...\(Bundle.main.shortVersion)(\(Bundle.main.bundleVersion))")
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        AudioManager.shared.pause()
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        pendingShortcutItem = shortcutItem
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        checkServerData()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        guard LoginManager.shared.isLoggedIn || !(window.rootViewController is HomeContainerViewController) else {
            cleanForLogout()
            return
        }
        WebSocketService.shared.reconnectIfNeeded()
        cancelBackgroundTask()

        if let conversationId = UIApplication.currentConversationId(), UIApplication.shared.applicationState == .active {
            SendMessageService.shared.sendReadMessages(conversationId: conversationId)
        }
        
        if let item = pendingShortcutItem, let itemType = UIApplicationShortcutItem.ItemType(rawValue: item.type) {
            switch itemType {
            case .scanQrCode:
                pushCameraViewController()
            case .wallet:
                pushWalletViewController()
            case .myQrCode:
                showMyQrCode()
            }
        }
        pendingShortcutItem = nil
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AccountAPI.shared.updateSession(deviceToken: deviceToken.toHexString())
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.newData)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return LoginManager.shared.isLoggedIn && UrlWindow.checkUrl(url: url)
    }
    
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        guard LoginManager.shared.account == nil else {
            return
        }
        guard let data = AppGroupUserDefaults.Account.serializedAccount else {
            return
        }
        LoginManager.shared.account = try? JSONDecoder.default.decode(Account.self, from: data)
        configAnalytics()
        if LoginManager.shared.isLoggedIn && !(window.rootViewController is HomeContainerViewController) {
            checkLogin()
        }
    }
    
}

extension AppDelegate: PKPushRegistryDelegate {
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        voipToken = pushCredentials.token.toHexString()
        if LoginManager.shared.isLoggedIn {
            AccountAPI.shared.updateSession(voipToken: voipToken)
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        checkServerData(isPushKit: true)
    }
    
}

extension AppDelegate {
    
    @objc func updateApplicationIconBadgeNumber() {
        DispatchQueue.global().async {
            let number = min(99, ConversationDAO.shared.getUnreadMessageCount())
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = number
            }
        }
    }
    
    @objc func cleanForLogout() {
        WKWebsiteDataStore.default().removeAllCookiesAndLocalStorage()
        BackupJobQueue.shared.cancelAllOperations()
        
        UIApplication.shared.setShortcutItemsEnabled(false)
        UIApplication.shared.applicationIconBadgeNumber = 1
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        UNUserNotificationCenter.current().removeAllNotifications()
        UIApplication.shared.unregisterForRemoteNotifications()
        
        let oldRootViewController = window.rootViewController
        window.rootViewController = LoginNavigationController.instance()
        oldRootViewController?.navigationController?.removeFromParent()
    }
    
    @objc func handleClockSkew() {
        guard !(window.rootViewController is ClockSkewViewController) else {
            return
        }
        window.rootViewController = makeInitialViewController()
    }
    
}

extension AppDelegate {
    
    private func checkLogin() {
        window.backgroundColor = .black
        if LoginManager.shared.isLoggedIn {
            window.rootViewController = makeInitialViewController()
            if ContactsManager.shared.authorization == .authorized && AppGroupUserDefaults.User.autoUploadsContacts {
                DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: {
                    PhoneContactAPI.shared.upload(contacts: ContactsManager.shared.contacts)
                })
            }
        } else {
            if UIApplication.shared.isProtectedDataAvailable {
                window.rootViewController = LoginNavigationController.instance()
            } else {
                window.rootViewController = R.storyboard.launchScreen().instantiateInitialViewController()
            }
        }
        UIApplication.shared.setShortcutItemsEnabled(LoginManager.shared.isLoggedIn)
        window.makeKeyAndVisible()
    }
    
    private func configAnalytics() {
        guard UIApplication.shared.isProtectedDataAvailable else {
            return
        }
        Reporter.registerUserInformation()
        AppGroupUserDefaults.User.updateLastUpdateOrInstallDateIfNeeded()
        MixinServices.printSignalLog = { (message: UnsafePointer<Int8>!) -> Void in
            let log = String(cString: message)
            Logger.write(log: log)
        }
    }
    
    private func checkJailbreak() {
        guard UIDevice.isJailbreak else {
            return
        }
        Keychain.shared.clearPIN()
    }
    
    private func checkServerData(isPushKit: Bool = false) {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        guard !AppGroupUserDefaults.User.needsUpgradeInMainApp else {
            return
        }
        WebSocketService.shared.reconnectIfNeeded()

        cancelBackgroundTask()
        self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.cancelBackgroundTask()
        })
        self.backgroundTime = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { (time) in
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
    
    private func updateSharedImageCacheConfig() {
        SDImageCacheConfig.default.maxDiskSize = 1024 * bytesPerMegaByte
        SDImageCacheConfig.default.maxDiskAge = -1
        SDImageCacheConfig.default.diskCacheExpireType = .accessDate
    }
    
    private func pushCameraViewController() {
        guard let navigationController = UIApplication.homeNavigationController else {
            return
        }
        
        func push() {
            if navigationController.viewControllers.last is CameraViewController {
               return
            }
            navigationController.pushViewController(withBackRoot: CameraViewController.instance())
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            push()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted) in
                guard granted else {
                    return
                }
                DispatchQueue.main.async {
                    push()
                }
            })
        case .denied, .restricted:
            navigationController.alertSettings(Localized.PERMISSION_DENIED_CAMERA)
        @unknown default:
            navigationController.alertSettings(Localized.PERMISSION_DENIED_CAMERA)
        }
    }
    
    private func pushWalletViewController() {
        guard let navigationController = UIApplication.homeNavigationController else {
            return
        }
        if let lastVC = (navigationController.viewControllers.last as? ContainerViewController)?.viewController, lastVC is WalletViewController {
            return
        }
        navigationController.pushViewController(withBackRoot: WalletViewController.instance())
    }
    
    private func showMyQrCode() {
        if let window = UIApplication.currentActivity()?.view.subviews.compactMap({ $0 as? QrcodeWindow }).first, window.isShowingMyQrCode {
            return
        }
        guard let account = LoginManager.shared.account else {
            return
        }
        let qrcodeWindow = QrcodeWindow.instance()
        qrcodeWindow.render(title: Localized.CONTACT_MY_QR_CODE,
                            description: Localized.MYQRCODE_PROMPT,
                            account: account)
        qrcodeWindow.presentView()
    }
    
}
