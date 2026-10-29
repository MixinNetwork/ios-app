import UIKit
import MixinServices

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    private(set) var mainWindow: Window?
    private(set) var galleryWindow: GalleryWindow?
    private(set) var screenLockWindow: Window?
    
    private var pendingShortcutItem: UIApplicationShortcutItem?
    private var pendingURL: (url: URL, source: UrlWindow.Source)?
    private var pendingUserActivity: NSUserActivity?
    
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePendingEventsIfNeeded),
            name: HomeContainerViewController.viewDidAppearNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePendingEventsIfNeeded),
            name: ScreenLockManager.didUnlockNotification,
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
        
        let mainWindow = Window(windowScene: windowScene)
        mainWindow.windowLevel = .normal
        mainWindow.backgroundColor = .black
        self.mainWindow = mainWindow
        setupRootViewController()
        ScreenLockManager.shared.lockScreenIfNeeded()
        
        if let shortcutItem = connectionOptions.shortcutItem {
            handleShortcutItem(shortcutItem)
        }
        if let urlContext = connectionOptions.urlContexts.first {
            handleURL(urlContext.url, from: .openURL)
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
        if WebSocketService.shared.isConnected {
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
        
        handlePendingEventsIfNeeded()
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        if let windowScene = scene as? UIWindowScene,
           windowScene.interfaceOrientation.isLandscape,
           let pipController = galleryWindow?.galleryViewController.pipController,
           pipController.isPictureInPictureActive
        {
            if #available(iOS 16.0, *) {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            } else {
                let portrait = Int(UIInterfaceOrientation.portrait.rawValue)
                UIDevice.current.setValue(portrait, forKey: "orientation")
            }
        }
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
        handleURL(url, from: .openURL)
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handleUserActivity(userActivity)
    }
    
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let handled = handleShortcutItem(shortcutItem)
        completionHandler(handled)
    }
    
    @available(iOS 16.0, *)
    func windowScene(
        _ windowScene: UIWindowScene,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        let window = window ?? windowScene.keyWindow
        if let gallery = window?.rootViewController as? GalleryViewController,
           gallery.currentItemViewController is GalleryVideoItemViewController
        {
            return .all
        } else {
            return .portrait
        }
    }
    
}

extension SceneDelegate {
    
    func prepareGalleryWindow() -> GalleryWindow? {
        if let galleryWindow {
            return galleryWindow
        } else if let scene = mainWindow?.windowScene {
            let window = GalleryWindow(windowScene: scene)
            window.windowLevel = .normal + 1
            self.galleryWindow = window
            return window
        } else {
            return nil
        }
    }
    
    func showGalleryWindow() {
        guard let galleryWindow else {
            return
        }
        galleryWindow.isHidden = false
        updateKeyWindow()
        galleryWindow.layoutIfNeeded()
        // Commit the prepared gallery content before starting its transition animation.
        CATransaction.flush()
    }
    
    func hideGalleryWindow() {
        guard let galleryWindow else {
            return
        }
        galleryWindow.isHidden = true
        updateKeyWindow()
    }
    
    func dismissModalPresentations(completion: @escaping () -> Void) {
        let dismissModals = { [weak self] in
            guard let root = self?.mainWindow?.rootViewController else {
                completion()
                return
            }
            var controller: UIViewController? = root
            while let current = controller {
                if let coordinator = current.transitionCoordinator {
                    let waitsForTransition = coordinator.animate(alongsideTransition: nil) { _ in
                        DispatchQueue.main.async {
                            self?.dismissModalPresentations(completion: completion)
                        }
                    }
                    if waitsForTransition {
                        return
                    }
                }
                if current.isBeingPresented || current.isBeingDismissed {
                    DispatchQueue.main.async {
                        self?.dismissModalPresentations(completion: completion)
                    }
                    return
                }
                controller = current.presentedViewController
            }
            if root.presentedViewController != nil {
                root.dismiss(animated: true, completion: completion)
            } else {
                completion()
            }
        }
        if let gallery = galleryWindow?.galleryViewController, gallery.isPresented {
            gallery.dismiss(transitionViewInitialOffsetY: 0, completion: dismissModals)
        } else {
            dismissModals()
        }
    }
    
    func showScreenLockWindow(rootViewController: ScreenLockViewController) {
        guard screenLockWindow == nil, let windowScene = mainWindow?.windowScene else {
            return
        }
        windowScene.keyWindow?.endEditing(true)
        let screenLockWindow = Window(windowScene: windowScene)
        screenLockWindow.windowLevel = .normal + 2
        screenLockWindow.rootViewController = rootViewController
        self.screenLockWindow = screenLockWindow
        screenLockWindow.isHidden = false
        updateKeyWindow()
    }
    
    func hideScreenLockWindow() {
        screenLockWindow?.isHidden = true
        screenLockWindow?.rootViewController = nil
        screenLockWindow = nil
        updateKeyWindow()
    }
    
    private func updateKeyWindow() {
        // A transition or logout must never take focus away from the lock screen.
        if let screenLockWindow, !screenLockWindow.isHidden {
            screenLockWindow.makeKey()
        } else if let galleryWindow, !galleryWindow.isHidden {
            galleryWindow.makeKey()
        } else {
            mainWindow?.makeKey()
        }
    }
    
    private func tearDownGalleryWindow() {
        guard let galleryWindow else {
            return
        }
        galleryWindow.galleryViewController.tearDown()
        galleryWindow.isHidden = true
        galleryWindow.rootViewController = nil
        self.galleryWindow = nil
        updateKeyWindow()
    }
    
}

extension SceneDelegate {
    
    @objc func setupRootViewController() {
        guard let mainWindow else {
            return
        }
        tearDownGalleryWindow()
        if let account = LoginManager.shared.account {
            mainWindow.rootViewController = CheckSessionEnvironmentViewController(localAccount: account)
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
                mainWindow.rootViewController = LoginNavigationController()
            } else {
                mainWindow.rootViewController = ProtectedDataUnavailableViewController()
            }
        }
        UIApplication.shared.setShortcutItemsEnabled(LoginManager.shared.isLoggedIn)
        mainWindow.isHidden = false
        updateKeyWindow()
    }
    
    @objc private func setupLoginViewController() {
        pendingShortcutItem = nil
        pendingURL = nil
        pendingUserActivity = nil
        tearDownGalleryWindow()
        guard let mainWindow else {
            return
        }
        mainWindow.endEditing(true)
        mainWindow.rootViewController = LoginNavigationController()
        updateKeyWindow()
    }
    
    @objc private func handleClockSkew() {
        guard let mainWindow else {
            return
        }
        tearDownGalleryWindow()
        if let controller = mainWindow.rootViewController as? CheckSessionEnvironmentViewController,
           controller.contentViewController is ClockSkewViewController
        {
            // Do nothing, the view controller can handle the error by itself
        } else if let account = LoginManager.shared.account {
            mainWindow.rootViewController = CheckSessionEnvironmentViewController(localAccount: account)
        } else {
            mainWindow.rootViewController = LoginNavigationController()
        }
    }
    
}

extension SceneDelegate {
    
    private var isReadyToHandleEvents: Bool {
        guard LoginManager.shared.isLoggedIn else {
            return false
        }
        guard !ScreenLockManager.shared.isLocked else {
            return false
        }
        guard UIApplication.shared.homeContainerViewController != nil else {
            return false
        }
        return true
    }
    
    @discardableResult
    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard LoginManager.shared.isLoggedIn else {
            return false
        }
        guard isReadyToHandleEvents else {
            pendingShortcutItem = shortcutItem
            return true
        }
        pendingShortcutItem = nil
        return performShortcutItem(shortcutItem)
    }
    
    @discardableResult
    private func handleURL(_ url: URL, from source: UrlWindow.Source) -> Bool {
        guard LoginManager.shared.isLoggedIn else {
            return false
        }
        guard isReadyToHandleEvents else {
            pendingURL = (url, source)
            return true
        }
        pendingURL = nil
        return UrlWindow.checkUrl(url: url, from: source)
    }
    
    @discardableResult
    private func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        guard LoginManager.shared.isLoggedIn else {
            return false
        }
        guard isReadyToHandleEvents else {
            pendingUserActivity = userActivity
            return true
        }
        pendingUserActivity = nil
        return performUserActivity(userActivity)
    }
    
    @objc private func handlePendingEventsIfNeeded() {
        guard isReadyToHandleEvents else {
            return
        }
        if let shortcutItem = pendingShortcutItem {
            pendingShortcutItem = nil
            performShortcutItem(shortcutItem)
        }
        if let (url, source) = pendingURL {
            pendingURL = nil
            _ = UrlWindow.checkUrl(url: url, from: source)
        }
        if let userActivity = pendingUserActivity {
            pendingUserActivity = nil
            performUserActivity(userActivity)
        }
    }
    
    @discardableResult
    private func performShortcutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let itemType = UIApplicationShortcutItem.ItemType(rawValue: shortcutItem.type) else {
            return false
        }
        switch itemType {
        case .scanQrCode:
            UIApplication.shared.homeNavigationController?.pushQRCodeScannerViewController()
        case .wallet:
            UIApplication.shared.homeContainerViewController?.showWalletViewController()
        case .myQrCode:
            UIApplication.shared.homeContainerViewController?.presentMyQRCode()
        }
        return true
    }
    
    @discardableResult
    private func performUserActivity(_ userActivity: NSUserActivity) -> Bool {
        if SpotlightManager.isAvailable && SpotlightManager.shared.canContinue(activity: userActivity) {
            SpotlightManager.shared.contiune(activity: userActivity)
            return true
        } else if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            return UrlWindow.checkUrl(url: url, from: .userActivity)
        }
        return false
    }
    
}
