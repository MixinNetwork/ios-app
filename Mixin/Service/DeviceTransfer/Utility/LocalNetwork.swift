import Foundation
import Network
import MixinServices

class LocalNetworkAuthorization: NSObject {
    
    private var browser: NWBrowser?
    private var netService: NetService?
    private var completion: ((Bool) -> Void)?
    
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        Logger.general.info(category: "LocalNetworkAuthorization", message: "RequestAuthorization")
        
        guard #available(iOS 14, *) else {
            completion(true)
            return
        }
        
        assert(self.completion == nil && self.browser == nil && self.netService == nil, "Previous request is still pending")
        self.completion = completion
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let browser = NWBrowser(for: .bonjour(type: "_bonjour._tcp", domain: nil), using: parameters)
        browser.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                Logger.general.info(category: "LocalNetworkAuthorization", message: "Browser failed: \(error)")
            case .ready, .cancelled:
                break
            case .waiting:
                Logger.general.info(category: "LocalNetworkAuthorization", message: "Denied")
                self.reset()
                self.completion?(false)
            default:
                break
            }
        }
        self.browser = browser
        
        let netService = NetService(domain: "local.", type:"_lnp._tcp.", name: "LocalNetworkAuthorization", port: 39393)
        netService.delegate = self
        self.netService = netService
        
        browser.start(queue: .main)
        netService.publish()
    }
    
    private func reset() {
        browser?.cancel()
        browser = nil
        netService?.stop()
        netService = nil
    }
    
}

extension LocalNetworkAuthorization : NetServiceDelegate {
    
    func netServiceDidPublish(_ sender: NetService) {
        Logger.general.info(category: "LocalNetworkAuthorization", message: "Granted")
        reset()
        completion?(true)
    }
    
}
