//
//  ViewController.swift
//  MixinAppGroupAccess
//
//  Created by wuyuehyang on 2020/11/2.
//  Copyright © 2020 Mixin. All rights reserved.
//

import UIKit
import GCDWebServer

class ViewController: UIViewController {
    
    @IBOutlet weak var serverStatusLabel: UILabel!
    @IBOutlet weak var serverURLTextField: UITextField!
    
    let appGroupIdentifier = "group.one.mixin.messenger"
    
    private let urlSession = URLSession(configuration: .default)
    
    private var server: GCDWebDAVServer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Request network permission for devices sold in mainland China
        let task = urlSession.dataTask(with: URL(string: "https://www.baidu.com")!)
        task.resume()
        
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        server = GCDWebDAVServer(uploadDirectory: documentsURL.path)
        server.delegate = self
        server.start(withPort: 80, bonjourName: "MixinAppGroup")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    @IBAction func copyServerURL(_ sender: Any) {
        UIPasteboard.general.string = serverURLTextField.text
    }
    
}

extension ViewController: GCDWebDAVServerDelegate {
    
    func webServerDidStart(_ server: GCDWebServer) {
        serverStatusLabel.text = "ON"
    }
    
    func webServerDidStop(_ server: GCDWebServer) {
        serverStatusLabel.text = "OFF"
    }
    
    func webServerDidCompleteBonjourRegistration(_ server: GCDWebServer) {
        serverURLTextField.text = server.bonjourServerURL?.absoluteString
    }
    
}
