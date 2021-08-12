import WebKit

final class ScriptMessageProxy: NSObject, WKScriptMessageHandler {
    
    weak var target: WKScriptMessageHandler?
    
    init(target: WKScriptMessageHandler) {
        self.target = target
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
    
}
