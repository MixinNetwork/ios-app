import UIKit
import WebKit
import StoreKit
import FirebaseCore
import FirebaseAnalytics
import FirebasePerformance
import FirebaseCrashlytics
import AppsFlyerLib
import SDWebImage
import SDWebImageLottieCoder
import SDWebImageSVGCoder
import MixinServices

final class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static let protectedDataReadyNotification = Notification.Name("one.mixin.services.AppDelegate.ProtectedDataReady")
    
    static var current: AppDelegate {
        UIApplication.shared.delegate as! AppDelegate
    }
    
    // Even if the app is deleted, some items like the App Group Keychain will remain in the system.
    // When a user uninstalls and reinstalls, they usually expect a completely fresh environment.
    // Checking this value allows for the necessary adjustments to meet that expectation.
    private(set) var isFirstLaunch: Bool? = nil
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        print("Documents URL:\n\(AppGroupContainer.documentsUrl.path)")
        #endif
        updateFirstLaunch(isProtectedDataAvailable: application.isProtectedDataAvailable)
        FirebaseApp.configure()
        MixinService.callMessageCoordinator = CallService.shared
        reporterClass = MainAppReporter.self
        reporter.configure()
        AppGroupUserDefaults.migrateIfNeeded()
        
        SDImageCacheConfig.default.maxDiskSize = 1024 * bytesPerMegaByte
        SDImageCacheConfig.default.maxDiskAge = -1
        SDImageCacheConfig.default.diskCacheExpireType = .accessDate
        SDImageCodersManager.shared.addCoder(WebPImageDecoder.shared)
        SDImageCodersManager.shared.addCoder(SDImageLottieCoder.shared)
        SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)
        
        _ = ReachabilityManger.shared
        _ = DarwinNotificationManager.shared
        _ = CacheableAssetFileManager.shared
        UNUserNotificationCenter.current().setNotificationCategories([.message])
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        // [_UIAppearance setSectionHeaderTopPadding:] not working on macOS 11.6 (disguised as iOS 14.7)
        if !ProcessInfo.processInfo.isiOSAppOnMac {
            UITableView.appearance().sectionHeaderTopPadding = 0
        }
        
        if UIDevice.isJailbreak {
            Keychain.shared.clearPIN()
        }
        
        configAnalytics()
        if let key = MixinKeys.appsFlyer {
            AppsFlyerLib.shared().initialize(devKey: key, appId: appStoreAppID)
        } else {
            assertionFailure("Missing AppsFlyer key")
        }
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().registerSessionReadyListener {
            Logger.general.info(category: "AppsFlyer", message: "Session ready")
            self.startAppsFlyerIfReady()
        }
        addObservers()
        Logger.general.info(category: "AppDelegate", message: "App \(Bundle.main.shortVersionString)(\(Bundle.main.bundleVersion)) did finish launching with state: \(UIApplication.shared.applicationStateString), device: \(Device.current.machineName) \(ProcessInfo.processInfo.operatingSystemVersionString), id: \(Device.current.id)")
        if UIApplication.shared.applicationState == .background {
            MixinService.isStopProcessMessages = false
            WebSocketService.shared.connectIfNeeded()
            BackgroundMessagingService.shared.begin(caller: "didFinishLaunchingWithOptions",
                                                    stopsRegardlessApplicationState: false,
                                                    completionHandler: nil)
        }
        IAPTransactionObserver.global.listenToTransactionUpdates()
        return true
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        AppGroupUserDefaults.isRunningInMainApp = ReceiveMessageService.shared.processing
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationDiagnostic.global.token = .sent(Date())
        AccountAPI.updateSession(notificationToken: deviceToken.hexEncodedString()) { result in
            switch result {
            case .success:
                PushNotificationDiagnostic.global.registration = .success(Date())
            case .failure(let error):
                PushNotificationDiagnostic.global.registration = .failed(error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard LoginManager.shared.isLoggedIn else {
                        return
                    }
                    self?.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        PushNotificationDiagnostic.global.token = .failed(error)
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.newData)
    }
    
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        updateFirstLaunch(isProtectedDataAvailable: true)
        if LoginManager.shared.account == nil {
            LoginManager.shared.reloadAccountFromUserDefaults()
            configAnalytics()
            NotificationCenter.default.post(
                name: Self.protectedDataReadyNotification,
                object: self
            )
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let isActive = UIApplication.shared.applicationState == .active
        Logger.general.info(category: "AppDelegate", message: "Received remote notification, app is active: \(isActive)")

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
        NotificationCenter.default.addObserver(self, selector: #selector(webSocketDidConnect), name: WebSocketService.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(JobService.shared, selector: #selector(JobService.restoreJobs), name: WebSocketService.didSendListPendingMessageNotification, object: nil)
    }

    @objc func webSocketDidConnect() {
        guard canProcessMessages, UIApplication.isApplicationActive else {
            return
        }

        if ReachabilityManger.shared.isReachableOnEthernetOrWiFi {
            if AppGroupUserDefaults.User.autoBackup != .off {
                BackupJobQueue.shared.addJob(job: BackupJob())
            }
            if AppGroupUserDefaults.Account.canRestoreMedia {
                BackupJobQueue.shared.addJob(job: RestoreJob())
            }
        }

        if let date = AppGroupUserDefaults.Crypto.oneTimePrekeyRefreshDate, -date.timeIntervalSinceNow > 3600 * 2 {
            ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(request: .allAssets))
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
        WKWebsiteDataStore.default().removeAuthenticationRelatedData()
        BackupJobQueue.shared.cancelAllOperations()
        WalletConnectService.shared.disconnectAllSessions()
        Web3PopupCoordinator.rejectAllPopups()
        
        UIApplication.shared.setShortcutItemsEnabled(false)
        UIApplication.shared.applicationIconBadgeNumber = 1
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        UNUserNotificationCenter.current().removeAllNotifications()
        UIApplication.shared.unregisterForRemoteNotifications()
        
        Analytics.setUserID(nil)
        AppsFlyerLib.shared().customerUserID = nil
    }
    
}

extension AppDelegate {
    
    private func updateFirstLaunch(isProtectedDataAvailable: Bool) {
        guard isProtectedDataAvailable else {
            return
        }
        if AppGroupUserDefaults.firstLaunchDate == nil {
            isFirstLaunch = true
            AppGroupUserDefaults.firstLaunchDate = Date()
        } else {
            isFirstLaunch = false
        }
    }
    
    private func configAnalytics() {
        guard UIApplication.shared.isProtectedDataAvailable else {
            return
        }
        AppGroupUserDefaults.User.updateLastUpdateOrInstallDateIfNeeded()
        if let account = LoginManager.shared.account {
            reporter.registerUserInformation(account: account)
        }
        MixinServices.printSignalLog = { (message: UnsafePointer<Int8>!) -> Void in
            let log = String(cString: message)
            if log.hasPrefix("No sender key for:"), let conversationId = log.suffix(char: ":")?.substring(endChar: ":").trim() {
                Logger.conversation(id: conversationId).info(category: "Signal", message: log)
            } else {
                Logger.general.info(category: "Signal", message: log)
            }
        }
    }
    
}

extension AppDelegate {
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if let homeContainerVC = UIApplication.shared.homeContainerViewController, homeContainerVC.galleryIsOnTopMost,  homeContainerVC.galleryViewController.currentItemViewController is GalleryVideoItemViewController {
            return .all
        }
        return .portrait
    }
    
}

extension AppDelegate {
    
    func startAppsFlyerIfReady() {
        guard AppsFlyerLib.shared().isSessionReady() else {
            return
        }
        var customData: [String: Any] = [:]
        if let appInstanceID = Analytics.appInstanceID() {
            customData["app_instance_id"] = appInstanceID
        } else {
            assertionFailure("Missing app_instance_id")
        }
        Task {
            do {
                let sessionID = try await Analytics.sessionID()
                customData["ga_session_id"] = sessionID
            } catch {
                let nsError = error as NSError
                if nsError.domain == "com.google.gmp.measurement.ErrorDomain" && nsError.code == 13 {
                    // Analytics uninitialized, commonly caused by poor/blocked network reachability
                    // to Google's endpoints rather than a Mixin-side bug, only log it locally.
                    Logger.general.error(category: "AppsFlyer", message: "Get ga_session_id: \(error)")
                } else {
                    reporter.report(error: error)
                }
            }
            Logger.general.debug(category: "AppsFlyer", message: "Reporting \(customData)")
            AppsFlyerLib.shared().customData = customData
            if let userID = LoginManager.shared.account?.userID {
                AppsFlyerLib.shared().customerUserID = Reporter.userIDHash(userID: userID)
            } else {
                AppsFlyerLib.shared().customerUserID = nil
            }
            do {
                try await AppsFlyerLib.shared().start()
            } catch {
                reporter.report(error: error)
            }
        }
    }
    
}

extension AppDelegate : AppsFlyerLibDelegate {

    // Handle Organic/Non-organic installation
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
        guard let status = conversionInfo["af_status"] as? String else {
            return
        }

        reporter.updateUserProperty(key: "af_source", value: status)
        if status == "Non-organic" {
            if let mediaSource = conversionInfo["media_source"] as? String, !mediaSource.isEmpty {
                reporter.updateUserProperty(key: "af_media_source", value: mediaSource)
            }
            
            if let campaign = conversionInfo["campaign"] as? String, !campaign.isEmpty {
                reporter.updateUserProperty(key: "af_campaign", value: campaign)
            }
        }
        Logger.general.debug(category: "AppsFlyer", message: "status \(conversionInfo)")
    }
 
    func onConversionDataFail(_ error: any Error) {
        Logger.general.error(category: "AppsFlyer", message: "onConversionDataFail: \(error)")
    }
    
}
