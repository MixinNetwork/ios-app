import WebKit
import MixinServices

final class WebViewMessageHandler: NSObject, WKScriptMessageHandler {
    
    protocol Delegate: AnyObject {
        func webViewMessageHander(_ handler: WebViewMessageHandler, didReceiveMessage message: Message)
        func webViewMessageHanderGetCurrentURL(_ handler: WebViewMessageHandler) -> URL?
        func webViewMessageHander(_ handler: WebViewMessageHandler, acceptsWalletProvisioningFrom frame: WKFrameInfo) -> Bool
    }
    
    enum Name: String, CaseIterable {
        case mixinContext = "MixinContext"
        case reloadTheme = "reloadTheme"
        case playlist = "playlist"
        case close = "close"
        case getTIPAddress = "getTipAddress"
        case tipSign = "tipSign"
        case getAssets = "getAssets"
        case web3Bridge = "_mw_"
        case signBotSignature = "signBotSignature"
        case openInBrowser = "openInBrowser"
        case startWalletProvisioning = "startWalletProvisioning"
        case completeWalletProvisioning = "completeWalletProvisioning"
    }

    struct ApplePayProvisioningStart {
        let requestID: UUID
        let cardholderName: String?
        let primaryAccountSuffix: String
        let primaryAccountIdentifier: String?
        let localizedDescription: String
        let paymentNetwork: String
    }

    enum ApplePayProvisioningCompletion {
        case payload(UUID, Data, Data, Data)
        case failure(UUID, String)
    }
    
    enum Message {
        case reloadTheme
        case close
        case getTIPAddress(callback: String)
        case tipSign(callback: String)
        case getAssets(assetIDs: [String], callback: String)
        case web3Bridge([String: Any])
        case signBotSignature(callback: String)
        case openInBrowser(URL)
        case startApplePayProvisioning(ApplePayProvisioningStart)
        case completeApplePayProvisioning(ApplePayProvisioningCompletion)
    }
    
    private enum AppSigningError: Error {
        case noSuchApp
        case unauthorizedResource
    }
    
    weak var delegate: Delegate?
    
    init(delegate: Delegate) {
        self.delegate = delegate
        super.init()
    }
    
    deinit {
        Logger.general.debug(category: "WebViewMessageHandler", message: "Deinited")
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let handlerName = Name(rawValue: message.name) else {
            return
        }
        switch handlerName {
        case .mixinContext:
            break
        case .reloadTheme:
            delegate?.webViewMessageHander(self, didReceiveMessage: .reloadTheme)
        case .playlist:
            if let body = message.body as? [String] {
                let playlist = body.compactMap(PlaylistItem.init)
                if !playlist.isEmpty {
                    PlaylistManager.shared.play(index: 0, in: playlist, source: .remote)
                }
            }
        case .close:
            delegate?.webViewMessageHander(self, didReceiveMessage: .close)
        case .getTIPAddress:
            if let body = message.body as? [String], body.count == 2 {
                // let chainId = body[0]
                let callback = body[1]
                let address = "" // Empty address as rejection
                let result = "\(callback)('\(address)');"
                delegate?.webViewMessageHander(self, didReceiveMessage: .getTIPAddress(callback: result))
            }
        case .tipSign:
            if let body = message.body as? [String], body.count == 3 {
                // let chainId = body[0]
                // let message = body[1]
                let callback = body[2]
                let signature = "" // Empty signature as rejection
                let result = "\(callback)('\(signature)');"
                delegate?.webViewMessageHander(self, didReceiveMessage: .tipSign(callback: result))
            }
        case .getAssets:
            if let body = message.body as? [Any],
               body.count == 2,
               let assetIDs = body[0] as? [String],
               let callback = body[1] as? String
            {
                delegate?.webViewMessageHander(self, didReceiveMessage: .getAssets(assetIDs: assetIDs, callback: callback))
            }
        case .web3Bridge:
            let body: [String: Any]
            if let string = message.body as? String,
               let data = string.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data, options: []),
               let dict = object as? [String: Any]
            {
                body = dict
            } else if let object = message.body as? [String: Any] {
                body = object
            } else {
                return
            }
            delegate?.webViewMessageHander(self, didReceiveMessage: .web3Bridge(body))
        case .signBotSignature:
            guard
                let url = delegate?.webViewMessageHanderGetCurrentURL(self),
                let messageBody = message.body as? [Any],
                messageBody.count >= 6,
                let appID = messageBody[0] as? String,
                let reloadPublicKey = messageBody[1] as? Bool,
                let method = messageBody[2] as? String,
                let path = messageBody[3] as? String,
                let body = messageBody[4] as? String,
                let callback = messageBody[5] as? String
            else {
                return
            }
            DispatchQueue.global().async { [weak delegate] in
                do {
                    let app: App?
                    if let localApp = AppDAO.shared.getApp(appId: appID),
                       localApp.resourcePatterns(accepts: url)
                    {
                        app = localApp
                    } else {
                        switch UserAPI.showUser(userId: appID) {
                        case .success(let response):
                            UserDAO.shared.updateUsers(users: [response])
                            app = response.app
                        case .failure:
                            app = nil
                        }
                    }
                    guard let app else {
                        throw AppSigningError.noSuchApp
                    }
                    guard app.resourcePatterns(accepts: url) else {
                        throw AppSigningError.unauthorizedResource
                    }
                    let signature = try RouteAPI.sign(
                        appID: appID,
                        reloadPublicKey: reloadPublicKey,
                        method: method,
                        path: path,
                        body: body.data(using: .utf8)
                    )
                    DispatchQueue.main.async {
                        let result = "\(callback)('\(signature.timestamp)', '\(signature.signature)');"
                        delegate?.webViewMessageHander(self, didReceiveMessage: .signBotSignature(callback: result))
                    }
                } catch {
                    DispatchQueue.main.async {
                        let result = "\(callback)(null);"
                        delegate?.webViewMessageHander(self, didReceiveMessage: .signBotSignature(callback: result))
                    }
                }
            }
        case .openInBrowser:
            guard let urlString = message.body as? String,
                  let url = Self.openInBrowserURL(from: urlString)
            else {
                return
            }
            delegate?.webViewMessageHander(self, didReceiveMessage: .openInBrowser(url))
        case .startWalletProvisioning:
            guard delegate?.webViewMessageHander(self, acceptsWalletProvisioningFrom: message.frameInfo) == true,
                  let message = Self.applePayProvisioningStartMessage(from: message.body)
            else {
                return
            }
            delegate?.webViewMessageHander(self, didReceiveMessage: message)
        case .completeWalletProvisioning:
            guard delegate?.webViewMessageHander(self, acceptsWalletProvisioningFrom: message.frameInfo) == true,
                  let message = Self.applePayProvisioningCompletionMessage(from: message.body)
            else {
                return
            }
            delegate?.webViewMessageHander(self, didReceiveMessage: message)
        }
    }

}

extension WebViewMessageHandler.Delegate {

    func webViewMessageHander(_ handler: WebViewMessageHandler, acceptsWalletProvisioningFrom frame: WKFrameInfo) -> Bool {
        false
    }

}

extension WebViewMessageHandler {

    static func applePayProvisioningStartMessage(from body: Any) -> Message? {
        guard let body = jsonObject(from: body),
              let request = applePayProvisioningStart(from: body)
        else {
            return nil
        }
        return .startApplePayProvisioning(request)
    }

    static func applePayProvisioningCompletionMessage(from body: Any) -> Message? {
        guard let body = jsonObject(from: body),
              let requestIDString = body["requestId"] as? String,
              let requestID = UUID(uuidString: requestIDString)
        else {
            return nil
        }
        if let error = nonemptyString(body["error"]) {
            return .completeApplePayProvisioning(.failure(requestID, error))
        }
        guard let activationData = base64Data(body["activationData"]),
              let encryptedPassData = base64Data(body["encryptedPassData"]),
              let ephemeralPublicKey = base64Data(body["ephemeralPublicKey"])
        else {
            return nil
        }
        return .completeApplePayProvisioning(
            .payload(requestID, activationData, encryptedPassData, ephemeralPublicKey)
        )
    }

    private static func jsonObject(from value: Any) -> [String: Any]? {
        guard let value = value as? String,
              let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else {
            return nil
        }
        return object as? [String: Any]
    }

    private static func applePayProvisioningStart(from body: [String: Any]) -> ApplePayProvisioningStart? {
        guard let requestIDString = body["requestId"] as? String,
              let requestID = UUID(uuidString: requestIDString),
              let primaryAccountSuffix = nonemptyString(body["primaryAccountSuffix"]),
              let localizedDescription = nonemptyString(body["localizedDescription"]),
              let paymentNetwork = nonemptyString(body["paymentNetwork"])
        else {
            return nil
        }
        return ApplePayProvisioningStart(
            requestID: requestID,
            cardholderName: nonemptyString(body["cardholderName"]),
            primaryAccountSuffix: primaryAccountSuffix,
            primaryAccountIdentifier: nonemptyString(body["primaryAccountIdentifier"]),
            localizedDescription: localizedDescription,
            paymentNetwork: paymentNetwork
        )
    }

    private static func nonemptyString(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func base64Data(_ value: Any?) -> Data? {
        guard let value = nonemptyString(value) else {
            return nil
        }
        return Data(base64Encoded: value)
    }

    static func openInBrowserURL(from value: String) -> URL? {
        let urlString = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty,
              !["undefined", "null"].contains(urlString.lowercased())
        else {
            return nil
        }

        guard let url = URL(string: urlString),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false
        else {
            return nil
        }
        return url
    }

}
