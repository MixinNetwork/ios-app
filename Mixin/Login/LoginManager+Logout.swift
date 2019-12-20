import Foundation

extension LoginManager {
    
    func logout(from: String) {
        guard account != nil else {
            return
        }
        UIApplication.shared.setShortcutItemsEnabled(false)
        Logger.write(log: "===========logout...from:\(from)")
        AppGroupUserDefaults.User.isLogoutByServer = true
        DispatchQueue.main.async {
            self.account = nil
            Keychain.shared.clearPIN()
            WebSocketService.shared.disconnect()
            BackupJobQueue.shared.cancelAllOperations()
            AppGroupUserDefaults.Account.clearAll()
            SignalDatabase.shared.logout()
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = 1
                UIApplication.shared.applicationIconBadgeNumber = 0
                UNUserNotificationCenter.current().removeAllNotifications()
                UIApplication.shared.unregisterForRemoteNotifications()

                MixinWebView.clearCookies()
                let oldRootViewController = AppDelegate.current.window.rootViewController
                AppDelegate.current.window.rootViewController = LoginNavigationController.instance()
                oldRootViewController?.navigationController?.removeFromParent()
            }
        }
    }
    
}
