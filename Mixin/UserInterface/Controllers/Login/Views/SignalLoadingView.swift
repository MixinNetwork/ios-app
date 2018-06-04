import UIKit
import Bugsnag

class SignalLoadingView: BottomSheetView {


    private var dismissBlock: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        windowBackgroundColor = UIColor.clear
    }

    func presentPopupControllerAnimated(dismissBlock: @escaping (() -> Void)) {
        super.presentPopupControllerAnimated()
        self.dismissBlock = dismissBlock

        let startTime = Date()
        DispatchQueue.global().async { [weak self] in
            repeat {
                switch SignalKeyAPI.shared.pushSignalKeys(key: try! PreKeyUtil.generateKeys()) {
                case .success:
                    CryptoUserDefault.shared.isLoaded = true
                    MixinDatabase.shared.deleteAll(table: SentSenderKey.tableName)

                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        MixinWebView.clearCookies()
                        WebSocketService.shared.connect()
                        let time = Date().timeIntervalSince(startTime)
                        if time < 2 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + (2 - time), execute: {
                                weakSelf.dismissPopupControllerAnimated()
                            })
                        } else {
                            weakSelf.dismissPopupControllerAnimated()
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
                    Bugsnag.notifyError(error)
                }
            } while true
        }
    }

    override func dismissPopupControllerAnimated() {
        guard CryptoUserDefault.shared.isLoaded else {
            return
        }
        super.dismissPopupControllerAnimated()
        dismissBlock?()
    }

    class func instance() -> SignalLoadingView {
        return Bundle.main.loadNibNamed("SignalLoadingView", owner: nil, options: nil)?.first as! SignalLoadingView
    }

}
