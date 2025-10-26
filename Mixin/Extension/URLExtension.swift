import Foundation
import MobileCoreServices

extension URL {
    
    static let blank                = URL(string: "about:blank")!
    static let mixinMessenger       = URL(string: "https://messenger.mixin.one")!
    static let shortMixinMessenger  = URL(string: "https://mixin.one/mm")!
    static let terms                = URL(string: "https://mixin.one/pages/terms")!
    static let privacy              = URL(string: "https://mixin.one/pages/privacy")!
    static let aboutEncryption      = URL(string: "https://mixin.one/pages/1000007")!
    static let tip                  = URL(string: "https://tip.id")!
    static let customerService      = URL(string: "https://go.crisp.chat/chat/embed/?website_id=52662bba-be49-4b06-9edc-7baa9a78f714")!
    static let openSource           = URL(string: "https://github.com/MixinNetwork/ios-app")!
    static let referral             = URL(string: R.string.localizable.url_referral())!
    static let recoveryContact      = URL(string: R.string.localizable.url_recovery_contact())!
    static let unsupportedMessage   = URL(string: R.string.localizable.url_unsupported_message())!
    static let deleteAccount        = URL(string: R.string.localizable.url_delete_account())!
    static let disappearingMessage  = URL(string: R.string.localizable.url_disappearing_message())!
    static let deposit              = URL(string: R.string.localizable.url_deposit())!
    static let depositSuspended     = URL(string: R.string.localizable.url_deposit_suspended())!
    static let forgetPIN            = URL(string: R.string.localizable.url_forget_pin())!
    static let apiUpgrade           = URL(string: R.string.localizable.url_api_upgrade())!
    static let cantReceiveOTP       = URL(string: R.string.localizable.url_cant_receive_otp())!
    static let recallMessage        = URL(string: R.string.localizable.url_recall_message())!
    static let support              = URL(string: R.string.localizable.url_support())!
    static let watchWallet          = URL(string: R.string.localizable.url_watch_wallet())!
    static let whatIsPIN            = URL(string: R.string.localizable.url_what_is_pin())!
    static let lightningAddress     = URL(string: R.string.localizable.url_lightning_address())!
    static let crossWalletTransactionFree = URL(string: R.string.localizable.url_cross_wallet_transaction_free())!
    
    func getKeyVals() -> [String: String] {
        return URLComponents(url: self, resolvingAgainstBaseURL: true)?.getKeyVals() ?? [:]
    }

    var fileExists: Bool {
        return (try? checkResourceIsReachable()) ?? false
    }
    
    var fileSize: Int64 {
        return (try? resourceValues(forKeys: [.fileSizeKey]))?.allValues[.fileSizeKey] as? Int64 ?? -1
    }

    static func createTempUrl(fileExtension: String) -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString.lowercased()).\(fileExtension)")
    }

    var childFileCount: Int {
        guard FileManager.default.directoryExists(atPath: path) else {
            return 0
        }
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return 0
        }
        return files.count
    }
    
    var isStoredCloud: Bool {
        return FileManager.default.isUbiquitousItem(at: self)
    }
    
}

extension URL {

    func getMimeType() -> String? {
        guard let extUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil) else {
            return nil
        }

        guard let mimeUTI = UTTypeCopyPreferredTagWithClass(extUTI.takeUnretainedValue(), kUTTagClassMIMEType) else {
            return nil
        }

        return String(mimeUTI.takeUnretainedValue())
    }
    
    func suffix(base: URL) -> String {
        return String(path.suffix(path.count - base.path.count))
    }
}

extension URLComponents {

    func getKeyVals() -> [String: String] {
        var results = [String: String]()
        if let items = queryItems {
            for item in items {
                results.updateValue(item.value ?? "", forKey: item.name)
            }
        }
        return results
    }

}
