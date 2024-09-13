//
//  PINIteratorView.swift
//  MixinDebug
//
//  Created by wuyuehyang on 1/19/22.
//  Copyright © 2022 Mixin. All rights reserved.
//

import Foundation
import SwiftUI
import MixinServices

struct PINIteratorView: View {
    
    private let iterator: UInt64
    
    @ObservedObject private var test: PINIteratorTest
    
    var body: some View {
        List {
            Section {
                HStack {
                    Button(action: test.start) {
                        HStack {
                            Text("Start Test")
                            Spacer()
                            if test.isBusy {
                                ProgressView()
                            }
                        }
                    }.disabled(test.isBusy)
                }
            } footer: {
                Text("Current it: \(iterator)")
            }
        }
        .navigationTitle("PIN Iterator Test")
        .listStyle(GroupedListStyle())
    }
    
    init() {
        let iterator: UInt64 = PropertiesDAO.shared.unsafeValue(forKey: .iterator) ?? 0
        self.iterator = iterator
        self.test = PINIteratorTest(originalIterator: iterator)
    }
    
}
