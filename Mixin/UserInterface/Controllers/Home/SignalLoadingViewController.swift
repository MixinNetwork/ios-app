import UIKit

class SignalLoadingViewController: UIViewController {
    
    class func instance() -> SignalLoadingViewController {
        return Storyboard.home.instantiateViewController(withIdentifier: "signal") as! SignalLoadingViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        FileManager.default.writeLog(log: "SignalLoadingView...")
        let startTime = Date()
        DispatchQueue.global().async { [weak self] in
            try! SignalDatabase.shared.initDatabase()
            IdentityDAO.shared.saveLocalIdentity()

            repeat {
                switch SignalKeyAPI.shared.pushSignalKeys(key: try! PreKeyUtil.generateKeys()) {
                case .success:
                    CryptoUserDefault.shared.isLoaded = true
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        MixinWebView.clearCookies()
                        let time = Date().timeIntervalSince(startTime)
                        if time < 2 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + (2 - time), execute: {
                                weakSelf.dismiss()
                            })
                        } else {
                            weakSelf.dismiss()
                        }
                    }
                    return
                case let .failure(error):
                    guard error.code != 401 else {
                        return
                    }
                    while AccountAPI.shared.didLogin && !NetworkManager.shared.isReachable {
                        Thread.sleep(forTimeInterval: 2)
                    }
                    Thread.sleep(forTimeInterval: 2)
                    UIApplication.traceError(error)
                }
            } while true
        }
    }
    
    private func dismiss() {
        AppDelegate.current.window.rootViewController = makeInitialViewController()
    }
    
}
