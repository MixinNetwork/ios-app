import WebKit
import MixinServices

final class WebViewMessageHandler: NSObject, WKScriptMessageHandler {
    
    protocol Delegate: AnyObject {
        func webViewMessageHander(_ handler: WebViewMessageHandler, didReceiveMessage message: Message)
        func webViewMessageHanderGetCurrentURL(_ handler: WebViewMessageHandler) -> URL?
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
    }
    
    enum Message {
        case reloadTheme
        case close
        case getTIPAddress(callback: String)
        case tipSign(callback: String)
        case getAssets(assetIDs: [String], callback: String)
        case web3Bridge([String: Any])
        case signBotSignature(callback: String)
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
            delegate?.webViewMessageHander(self, didReceiveMessage: .reloadTheme)
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
        }
    }
    
}
