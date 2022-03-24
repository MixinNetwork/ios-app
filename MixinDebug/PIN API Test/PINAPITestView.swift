//
//  PINAPITestView.swift
//  MixinDebug
//
//  Created by wuyuehyang on 1/27/22.
//  Copyright © 2022 Mixin. All rights reserved.
//

import SwiftUI

struct PINAPITestView: View {
    
    @StateObject private var test = PINAPITest()
    
    @State private var isShowingPINAlert = false
    
    var body: some View {
        List {
            Section {
                Button {
                    isShowingPINAlert = true
                } label: {
                    HStack {
                        Text("Start Test")
                        Spacer()
                        if test.isRunning {
                            ProgressView()
                        }
                    }
                }.disabled(test.isRunning)
            }
            
            Section {
                ForEach(test.cases) { testCase in
                    HStack {
                        Text(testCase.name)
                        Spacer()
                        switch testCase.state {
                        case .waiting:
                            Spacer()
                        case .running:
                            ProgressView()
                        case .failed:
                            Text("❌")
                        case .succeed:
                            Text("✅")
                        }
                    }
                }
            }
        }
        .navigationTitle("PIN API Test")
        .listStyle(GroupedListStyle())
        .textFieldAlert(isPresented: $isShowingPINAlert, title: "Input your PIN", text: nil, placeholder: "PIN", keyboardType: .numberPad) { pin in
            if let pin = pin {
                test.start(pin: pin)
            }
        }
    }
    
}
