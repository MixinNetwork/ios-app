//
//  PINAPITest.swift
//  MixinDebug
//
//  Created by wuyuehyang on 1/27/22.
//  Copyright © 2022 Mixin. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import MixinServices

class PINAPITest: ObservableObject {
    
    class Case: ObservableObject, Identifiable {
        
        enum State {
            case waiting
            case running
            case succeed
            case failed
        }
        
        typealias OnFinished = (_ hasSucceeded: Bool) -> ()
        typealias Work = (@escaping OnFinished) -> ()
        
        let name: String
        
        @Published private(set) var state: State = .waiting
        
        private let work: Work
        
        init(name: String, work: @escaping Work) {
            self.name = name
            self.work = work
        }
        
        func run() {
            state = .running
            work { hasSucceeded in
                self.state = hasSucceeded ? .succeed : .failed
            }
        }
        
    }
    
    @Published private(set) var isRunning = false
    @Published private(set) var cases: [Case] = []
    
    private var pin = ""
    private var receivers: [AnyCancellable] = []
    
    init() {
        let uuid = "00000000-0000-0000-0000-000000000000"
        let cases = [
            Case(name: "Sign Collectible", work: { onFinished in
                CollectibleAPI.sign(requestId: uuid, pin: self.pin) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            Case(name: "Unlock Collectible", work: { onFinished in
                CollectibleAPI.sign(requestId: uuid, pin: self.pin) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            
            Case(name: "Show Emergency", work: { onFinished in
                EmergencyAPI.show(pin: self.pin) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            Case(name: "Delete Emergency", work: { onFinished in
                EmergencyAPI.delete(pin: self.pin) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            
            Case(name: "Sign Multisig", work: { onFinished in
                MultisigAPI.sign(requestId: uuid, pin: self.pin) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            Case(name: "Unlock Multisig", work: { onFinished in
                MultisigAPI.unlock(requestId: uuid, pin: self.pin) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            
            Case(name: "Payment Transfer", work: { onFinished in
                PaymentAPI.transfer(assetId: uuid, opponentId: uuid, amount: "0", memo: "", pin: self.pin, traceId: uuid) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            
            Case(name: "Save Address", work: { onFinished in
                let request = AddressRequest(assetId: uuid, destination: uuid, tag: "", label: "", pin: self.pin)
                WithdrawalAPI.save(address: request) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            
            Case(name: "Verify Emergency Contact", work: { onFinished in
                EmergencyAPI.verifyContact(pin: self.pin, id: uuid, code: "0000") { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            
            Case(name: "Multisig Payment Transaction", work: { onFinished in
                let opponent = OpponentMultisig(receivers: [], threshold: 0)
                let request = RawTransactionRequest(assetId: uuid,
                                                    opponentMultisig: opponent,
                                                    amount: "0",
                                                    pin: self.pin,
                                                    traceId: uuid, memo: "")
                PaymentAPI.transactions(transactionRequest: request, pin: self.pin) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            
            Case(name: "Withdrawl", work: { onFinished in
                let request = WithdrawalRequest(addressId: uuid,
                                                amount: "0",
                                                traceId: uuid,
                                                pin: self.pin,
                                                memo: "")
                WithdrawalAPI.withdrawal(withdrawal: request) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            
            Case(name: "Delete Address", work: { onFinished in
                WithdrawalAPI.delete(addressId: uuid, pin: self.pin) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            
            Case(name: "Verify PIN", work: { (onFinished) in
                AccountAPI.verify(pin: self.pin) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            Case(name: "Deactivate account", work: { (onFinished) in
                AccountAPI.deactiveAccount(pin: self.pin, verificationID: "0000") { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            Case(name: "Change Phone Number", work: { (onFinished) in
                let request = AccountRequest(code: "0000",
                                             registrationId: nil,
                                             pin: self.pin,
                                             sessionSecret: nil)
                AccountAPI.changePhoneNumber(verificationId: "0000", accountRequest: request) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            Case(name: "Update PIN", work: { (onFinished) in
                AccountAPI.updatePin(old: self.pin, new: "114514") { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
            Case(name: "Update PIN (Revert)", work: { (onFinished) in
                AccountAPI.updatePin(old: "114514", new: self.pin) { result in
                    self.validate(result: result, onFinished: onFinished)
                }
            }),
        ]
        self.cases = cases
        self.receivers = cases.enumerated().map { index, testCase in
            testCase.$state.sink { newState in
                switch newState {
                case .succeed, .failed:
                    if index + 1 < cases.count {
                        cases[index + 1].run()
                    } else {
                        self.isRunning = false
                    }
                default:
                    break
                }
                self.objectWillChange.send()
            }
        }
    }
    
    func start(pin: String) {
        assert(!isRunning)
        isRunning = true
        self.pin = pin
        cases.first?.run()
    }
    
    private func validate<Result>(result: MixinAPI.Result<Result>, onFinished: Case.OnFinished) {
        switch result {
        case .failure(.malformedPin), .failure(.incorrectPin):
            onFinished(false)
        default:
            onFinished(true)
        }
        self.objectWillChange.send()
    }
    
}
