//
//  LocalNetworkAuthorization.swift
//  MixinDebug
//
//  Created by wuyuehyang on 1/19/22.
//  Copyright © 2022 Mixin. All rights reserved.
//

import Foundation
import Network

class LocalNetworkAuthorization: NSObject {
    
    private var browser: NWBrowser?
    private var service: NetService?
    private var completion: ((Bool) -> Void)?
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        assert(browser == nil && service == nil && self.completion == nil, "Don't reuse this object")
        self.completion = completion
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_bonjour._tcp", domain: nil), using: parameters)
        browser.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                print(error.localizedDescription)
                break
            case .ready, .cancelled:
                break
            case .waiting:
                self.tearDown()
                self.completion?(false)
            default:
                break
            }
        }
        self.browser = browser
        
        let service = NetService(domain: "local.", type:"_lnp._tcp.", name: "Dummy", port: 9090)
        service.delegate = self
        self.service = service
        
        browser.start(queue: .main)
        service.publish()
    }
    
    private func tearDown() {
        browser?.cancel()
        browser = nil
        service?.stop()
        service = nil
        completion = nil
    }
    
}

extension LocalNetworkAuthorization: NetServiceDelegate {
    
    func netServiceDidPublish(_ sender: NetService) {
        let completion = self.completion
        tearDown()
        completion?(true)
    }
    
}
