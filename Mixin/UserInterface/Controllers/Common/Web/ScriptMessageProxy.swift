import WebKit
import MixinServices

final class ScriptMessageProxy: NSObject, WKScriptMessageHandler {
    
    weak var target: WKScriptMessageHandler?
    
    init(target: WKScriptMessageHandler) {
        self.target = target
        super.init()
        Logger.general.debug(category: "ScriptMessageProxy", message: "Init \(ObjectIdentifier(self))")
    }
    
    deinit {
        Logger.general.debug(category: "ScriptMessageProxy", message: "Deinit \(ObjectIdentifier(self))")
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
    
}
