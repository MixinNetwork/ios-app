import UIKit
import MixinServices

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    private(set) var window: Window?
    
    private var pendingShortcutItem: UIApplicationShortcutItem?
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setupRootViewController),
            name: AppDelegate.protectedDataReadyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setupLoginViewController),
            name: LoginManager.didLogoutNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClockSkew),
            name: MixinService.clockSkewDetectedNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        
        let window = Window(windowScene: windowScene)
        self.window = window
        setupRootViewController()
        ScreenLockManager.shared.lockScreenIfNeeded()
        
        if let shortcutItem = connectionOptions.shortcutItem {
            pendingShortcutItem = shortcutItem
        }
        
        if let urlContext = connectionOptions.urlContexts.first {
            _ = UrlWindow.checkURLNowOrAfterScreenUnlocked(url: urlContext.url, from: .openURL)
        }
        
        if let userActivity = connectionOptions.userActivities.first {
            handleUserActivity(userActivity)
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
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

        if let chatVC = UIApplication.shared.currentConversationViewController() {
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
                UIApplication.shared.homeNavigationController?.pushQRCodeScannerViewController()
            case .wallet:
                UIApplication.shared.homeContainerViewController?.showWalletViewController()
            case .myQrCode:
                UIApplication.shared.homeContainerViewController?.presentMyQRCode()
            }
        }
        pendingShortcutItem = nil
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        BackgroundMessagingService.shared.begin(
            caller: "sceneDidEnterBackground",
            stopsRegardlessApplicationState: true,
            completionHandler: nil
        )
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }
        _ = UrlWindow.checkURLNowOrAfterScreenUnlocked(url: url, from: .openURL)
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handleUserActivity(userActivity)
    }
    
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        pendingShortcutItem = shortcutItem
        if LoginManager.shared.isLoggedIn {
            if let itemType = UIApplicationShortcutItem.ItemType(rawValue: shortcutItem.type) {
                switch itemType {
                case .scanQrCode:
                    UIApplication.shared.homeNavigationController?.pushQRCodeScannerViewController()
                case .wallet:
                    UIApplication.shared.homeContainerViewController?.showWalletViewController()
                case .myQrCode:
                    UIApplication.shared.homeContainerViewController?.presentMyQRCode()
                }
            }
            pendingShortcutItem = nil
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }
    
    @available(iOS 16.0, *)
    func windowScene(
        _ windowScene: UIWindowScene,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.current.application(UIApplication.shared, supportedInterfaceOrientationsFor: window)
    }
    
    private func handleUserActivity(_ userActivity: NSUserActivity) {
        if SpotlightManager.isAvailable && SpotlightManager.shared.canContinue(activity: userActivity) {
            SpotlightManager.shared.contiune(activity: userActivity)
        } else if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            _ = UrlWindow.checkURLNowOrAfterScreenUnlocked(url: url, from: .userActivity)
        }
    }
    
}

extension SceneDelegate {
    
    @objc func setupRootViewController() {
        guard let window else {
            return
        }
        window.backgroundColor = .black
        if let account = LoginManager.shared.account {
            window.rootViewController = CheckSessionEnvironmentViewController(localAccount: account)
            if ContactsManager.shared.authorization == .authorized && AppGroupUserDefaults.User.autoUploadsContacts {
                DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: {
                    PhoneContactAPI.upload(contacts: ContactsManager.shared.contacts)
                })
            }
        } else {
            if UIApplication.shared.isProtectedDataAvailable {
                if AppDelegate.current.isFirstLaunch ?? false {
                    AppGroupKeychain.removeItemsForCurrentSession()
                }
                window.rootViewController = LoginNavigationController()
            } else {
                window.rootViewController = ProtectedDataUnavailableViewController()
            }
        }
        UIApplication.shared.setShortcutItemsEnabled(LoginManager.shared.isLoggedIn)
        window.makeKeyAndVisible()
    }
    
    @objc private func setupLoginViewController() {
        guard let window else {
            return
        }
        window.endEditing(true)
        window.rootViewController = LoginNavigationController()
    }
    
    @objc private func handleClockSkew() {
        guard let window else {
            return
        }
        if let controller = window.rootViewController as? CheckSessionEnvironmentViewController,
           controller.contentViewController is ClockSkewViewController
        {
            // Do nothing, the view controller can handle the error by itself
        } else if let account = LoginManager.shared.account {
            window.rootViewController = CheckSessionEnvironmentViewController(localAccount: account)
        } else {
            window.rootViewController = LoginNavigationController()
        }
    }
    
}
