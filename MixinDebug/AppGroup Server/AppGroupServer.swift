//
//  AppGroupServer.swift
//  MixinDebug
//
//  Created by wuyuehyang on 1/18/22.
//  Copyright © 2022 Mixin. All rights reserved.
//

import UIKit

class AppGroupServer: NSObject, ObservableObject {
    
    @Published var isOn = false {
        didSet {
            if !oldValue && isOn {
                turnOn()
            } else if oldValue && !isOn {
                turnOff()
            }
        }
    }
    
    @Published private(set) var isBusy = false
    @Published private(set) var address: String?
    
    private let server: GCDWebDAVServer
    
    override init() {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.one.mixin.messenger")!
        server = GCDWebDAVServer(uploadDirectory: containerURL.path)
        super.init()
        server.delegate = self
    }
    
    private func turnOn() {
        guard !isBusy else {
            return
        }
        isBusy = true
        let authorization = LocalNetworkAuthorization()
        authorization.requestAuthorization { [weak self] isAuthorized in
            guard let self = self else {
                return
            }
            if isAuthorized {
                self.server.start(withPort: 80, bonjourName: "MixinAppGroup")
            } else {
                self.isOn = false
                self.isBusy = false
            }
        }
    }
    
    private func turnOff() {
        guard !isBusy else {
            return
        }
        isBusy = true
        server.stop()
    }
    
}

extension AppGroupServer: GCDWebDAVServerDelegate {
    
    func webServerDidStart(_ server: GCDWebServer) {
        isOn = true
        isBusy = false
        UIApplication.shared.isIdleTimerDisabled = true
        address = server.bonjourServerURL?.absoluteString ?? server.serverURL?.absoluteString
    }
    
    func webServerDidStop(_ server: GCDWebServer) {
        isOn = false
        isBusy = false
        UIApplication.shared.isIdleTimerDisabled = false
        address = nil
    }
    
    func webServerDidCompleteBonjourRegistration(_ server: GCDWebServer) {
        address = server.bonjourServerURL?.absoluteString ?? server.serverURL?.absoluteString
    }
    
}
