//
//  FunctionsView.swift
//  MixinDebug
//
//  Created by wuyuehyang on 1/17/22.
//  Copyright © 2022 Mixin. All rights reserved.
//

import SwiftUI

struct FunctionsView: View {
    
    @ObservedObject private var server = AppGroupServer()
    
    var body: some View {
        Form {
            Section {
                Toggle("AppGroup Server", isOn: $server.isOn)
                    .disabled(server.isBusy)
                if let address = server.address {
                    Button {
                        UIPasteboard.general.string = address
                    } label: {
                        Text(address)
                            .foregroundColor(Color(UIColor.label))
                    }
                }
            } footer: {
                if server.address != nil {
                    Text("Tap to copy address")
                }
            }
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        FunctionsView()
    }
    
}
