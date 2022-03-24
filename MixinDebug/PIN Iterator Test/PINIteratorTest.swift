//
//  PINIteratorTest.swift
//  MixinDebug
//
//  Created by wuyuehyang on 1/19/22.
//  Copyright © 2022 Mixin. All rights reserved.
//

import Foundation
import MixinServices

class PINIteratorTest: ObservableObject {
    
    @Published var isBusy = false
    
    private class Validator {
        
        private let queue = DispatchQueue(label: "Validator")
        
        private var value: UInt64 = 0
        
        func validate(value: UInt64, index: Int) {
            queue.async {
                if value <= self.value {
                    fatalError()
                } else {
                    self.value = value
                }
                print("Validated: \(value) with index \(index)")
            }
        }
        
    }
    
    private let numberOfQueues = 3
    private let numberOfUpdates = 1000
    private let originalIterator: UInt64
    
    init(originalIterator: UInt64) {
        self.originalIterator = originalIterator
    }
    
    func start() {
        guard !isBusy else {
            fatalError("Call start once at a time")
        }
        isBusy = true
        
        let finishedQueueCountLock = NSLock()
        var numberOfFinishedQueues = 0 {
            didSet {
                if numberOfFinishedQueues == self.numberOfQueues {
                    DispatchQueue.main.async {
                        self.isBusy = false
                        PropertiesDAO.shared.set(self.originalIterator, forKey: .iterator)
                    }
                }
            }
        }
        
        let validator = Validator()
        let writeQueues = (0..<numberOfQueues).map { i in
            DispatchQueue(label: String(i))
        }
        
        for (index, queue) in writeQueues.enumerated() {
            queue.async {
                for _ in 0..<self.numberOfUpdates {
                    var iterator: UInt64 = 1
                    PropertiesDAO.shared.updateValue(forKey: .iterator, type: UInt64.self) { current in
                        if let current = current {
                            iterator = current + 1
                        } else {
                            iterator = 1
                        }
                        return iterator
                    }
                    validator.validate(value: iterator, index: index)
                }
                finishedQueueCountLock.lock()
                numberOfFinishedQueues += 1
                finishedQueueCountLock.unlock()
            }
        }
    }
    
}
