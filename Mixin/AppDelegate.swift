import UIKit
import UserNotifications
import SDWebImage
import YYImage
import AVFoundation
import WebKit
import FirebaseCore
import Lottie
import MixinServices

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static var current: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    lazy var mainWindow = Window(frame: UIScreen.main.bounds)
    
    private var pendingShortcutItem: UIApplicationShortcutItem?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        MixinService.callMessageCoordinator = CallService.shared
        reporterClass = CrashlyticalReporter.self
        reporter.configure()
        AppGroupUserDefaults.migrateIfNeeded()
        updateSharedImageCacheConfig()
        _ = ReachabilityManger.shared
        _ = DarwinNotificationManager.shared
        _ = CacheableAssetFileManager.shared
        UNUserNotificationCenter.current().setNotificationCategories([.message])
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        checkLogin()
        ScreenLockManager.shared.lockScreenIfNeeded()
        checkJailbreak()
        configAnalytics()
        pendingShortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem
        addObservers()
        Logger.write(log: "\n-----------------------\n[AppDelegate]...didFinishLaunching...\(Bundle.main.shortVersion)(\(Bundle.main.bundleVersion))...\(UIApplication.shared.applicationStateString)")
        if UIApplication.shared.applicationState == .background {
            MixinService.isStopProcessMessages = false
            WebSocketService.shared.connectIfNeeded()
            BackgroundMessagingService.shared.begin(caller: "didFinishLaunchingWithOptions",
                                                    stopsRegardlessApplicationState: false,
                                                    completionHandler: nil)
        }
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        pendingShortcutItem = shortcutItem
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        BackgroundMessagingService.shared.begin(caller: "applicationDidEnterBackground",
                                                stopsRegardlessApplicationState: true,
                                                completionHandler: nil)
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        AppGroupUserDefaults.isRunningInMainApp = true

        guard LoginManager.shared.isLoggedIn else {
            return
        }
        requestTimeout = 5
        BackgroundMessagingService.shared.end()
        MixinService.isStopProcessMessages = false
        if WebSocketService.shared.isConnected && WebSocketService.shared.isRealConnected {
            DispatchQueue.global().async {
                guard canProcessMessages else {
                    return
                }
                guard AppGroupUserDefaults.User.hasRestoreUploadAttachment else {
                    return
                }
                AppGroupUserDefaults.User.hasRestoreUploadAttachment = false
                JobService.shared.restoreUploadJobs()
            }
        }
        WebSocketService.shared.connectIfNeeded()

        if let chatVC = UIApplication.currentConversationViewController() {
            if chatVC.conversationId == AppGroupUserDefaults.User.currentConversationId && AppGroupUserDefaults.User.reloadConversation {
                AppGroupUserDefaults.User.reloadConversation = false
                chatVC.dataSource?.reload()
            }
            SendMessageService.shared.sendReadMessages(conversationId: chatVC.conversationId)
        } else {
            AppGroupUserDefaults.User.currentConversationId = nil
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
        LOTAnimationCache.shared().clear()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        AppGroupUserDefaults.isRunningInMainApp = ReceiveMessageService.shared.processing
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AccountAPI.updateSession(deviceToken: deviceToken.toHexString())
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.newData)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return LoginManager.shared.isLoggedIn && UrlWindow.checkUrl(url: url, ignoreUnsupportMixinSchema: false)
    }
    
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        if AppGroupUserDefaults.firstLaunchDate == nil {
            AppGroupUserDefaults.firstLaunchDate = Date()
        }
        guard LoginManager.shared.account == nil else {
            return
        }
        LoginManager.shared.reloadAccountFromUserDefaults()
        configAnalytics()
        if LoginManager.shared.isLoggedIn && !(mainWindow.rootViewController is HomeContainerViewController) {
            checkLogin()
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let isActive = UIApplication.shared.applicationState == .active
        Logger.write(log: "[AppDelegate] received remote notification...isActive:\(isActive)")

        guard LoginManager.shared.isLoggedIn, !AppGroupUserDefaults.User.needsUpgradeInMainApp else {
            completionHandler(.noData)
            return
        }
        guard !isActive else {
            completionHandler(.noData)
            return
        }
        MixinService.isStopProcessMessages = false
        WebSocketService.shared.connectIfNeeded()
        BackgroundMessagingService.shared.begin(caller: "didReceiveRemoteNotification",
                                                stopsRegardlessApplicationState: false,
                                                completionHandler: completionHandler)
    }
    
}

extension AppDelegate {
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateApplicationIconBadgeNumber), name: MixinService.messageReadStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cleanForLogout), name: LoginManager.didLogoutNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleClockSkew), name: MixinService.clockSkewDetectedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(webSocketDidConnect), name: WebSocketService.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(JobService.shared, selector: #selector(JobService.restoreJobs), name: WebSocketService.didSendListPendingMessageNotification, object: nil)
    }

    @objc func webSocketDidConnect() {
        guard canProcessMessages, UIApplication.isApplicationActive else {
            return
        }

        if ReachabilityManger.shared.isReachableOnEthernetOrWiFi {
            if AppGroupUserDefaults.User.autoBackup != .off || AppGroupUserDefaults.Account.hasUnfinishedBackup {
                BackupJobQueue.shared.addJob(job: BackupJob())
            }
            if AppGroupUserDefaults.Account.canRestoreMedia {
                BackupJobQueue.shared.addJob(job: RestoreJob())
            }
        }

        if let date = AppGroupUserDefaults.Crypto.oneTimePrekeyRefreshDate, -date.timeIntervalSinceNow > 3600 * 2 {
            ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob())
            ConcurrentJobQueue.shared.addJob(job: RefreshOneTimePreKeysJob())
        }
        AppGroupUserDefaults.Crypto.oneTimePrekeyRefreshDate = Date()
        ConcurrentJobQueue.shared.addJob(job: RefreshOffsetJob())
    }
    
    @objc func updateApplicationIconBadgeNumber() {
        DispatchQueue.global().async {
            guard LoginManager.shared.isLoggedIn, !AppGroupUserDefaults.User.needsUpgradeInMainApp, !MixinService.isStopProcessMessages else {
                return
            }
            let number = min(99, ConversationDAO.shared.getUnreadMessageCountWithoutMuted())
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
        
        let oldRootViewController = mainWindow.rootViewController
        mainWindow.rootViewController = LoginNavigationController.instance()
        oldRootViewController?.navigationController?.removeFromParent()
    }
    
    @objc func handleClockSkew() {
        if let viewController = mainWindow.rootViewController as? ClockSkewViewController {
            viewController.checkFailed()
        } else {
            mainWindow.rootViewController = makeInitialViewController()
        }
    }
    
}

extension AppDelegate {
    
    private func checkLogin() {
        mainWindow.backgroundColor = .black
        if LoginManager.shared.isLoggedIn {
            mainWindow.rootViewController = makeInitialViewController()
            if ContactsManager.shared.authorization == .authorized && AppGroupUserDefaults.User.autoUploadsContacts {
                DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: {
                    PhoneContactAPI.upload(contacts: ContactsManager.shared.contacts)
                })
            }
        } else {
            if UIApplication.shared.isProtectedDataAvailable {
                mainWindow.rootViewController = LoginNavigationController.instance()
            } else {
                mainWindow.rootViewController = R.storyboard.launchScreen().instantiateInitialViewController()
            }
        }
        UIApplication.shared.setShortcutItemsEnabled(LoginManager.shared.isLoggedIn)
        mainWindow.makeKeyAndVisible()
    }
    
    private func configAnalytics() {
        guard UIApplication.shared.isProtectedDataAvailable else {
            return
        }
        if AppGroupUserDefaults.firstLaunchDate == nil {
            AppGroupUserDefaults.firstLaunchDate = Date()
        }
        AppGroupUserDefaults.User.updateLastUpdateOrInstallDateIfNeeded()
        reporter.registerUserInformation()
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
    
    private func updateSharedImageCacheConfig() {
        SDImageCacheConfig.default.maxDiskSize = 1024 * bytesPerMegaByte
        SDImageCacheConfig.default.maxDiskAge = -1
        SDImageCacheConfig.default.diskCacheExpireType = .accessDate
    }
    
}

extension AppDelegate {
    
    private func pushCameraViewController() {
        guard let navigationController = UIApplication.homeNavigationController else {
            return
        }
        
        func push() {
            if navigationController.viewControllers.last is CameraViewController {
               return
            }
            let vc = CameraViewController.instance()
            vc.asQrCodeScanner = true
            navigationController.pushViewController(withBackRoot: vc)
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
        WalletViewController.presentWallet()
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

extension AppDelegate {
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if let homeContainerVC = UIApplication.homeContainerViewController, homeContainerVC.galleryIsOnTopMost,  homeContainerVC.galleryViewController.currentItemViewController is GalleryVideoItemViewController {
            return .all
        }
        return .portrait
        
    }
    
}
