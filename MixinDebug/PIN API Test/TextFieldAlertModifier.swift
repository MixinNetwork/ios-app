//
//  TextFieldAlertModifier.swift
//  MixinDebug
//
//  Created by wuyuehyang on 2/10/22.
//  Copyright © 2022 Mixin. All rights reserved.
//

import Foundation
import SwiftUI

extension View {

    public func textFieldAlert(
        isPresented: Binding<Bool>,
        title: String,
        text: String?,
        placeholder: String?,
        keyboardType: UIKeyboardType,
        action: @escaping (String?) -> Void
    ) -> some View {
        let modifier = TextFieldAlertModifier(isPresented: isPresented,
                                              title: title,
                                              text: text,
                                              placeholder: placeholder,
                                              keyboardType: keyboardType,
                                              action: action)
        return self.modifier(modifier)
    }
    
}

public struct TextFieldAlertModifier: ViewModifier {

    @State private var controller: UIAlertController?

    @Binding var isPresented: Bool

    let title: String
    let text: String?
    let placeholder: String?
    let keyboardType: UIKeyboardType
    let action: (String?) -> Void

    public func body(content: Content) -> some View {
        content.onChange(of: isPresented) { isPresented in
            if isPresented, controller == nil {
                let controller = makeAlertController()
                self.controller = controller
                UIApplication.shared.windows.first?.rootViewController?.present(controller, animated: true)
            } else if !isPresented, let controller = controller {
                controller.dismiss(animated: true)
                self.controller = nil
            }
        }
    }

    private func makeAlertController() -> UIAlertController {
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        controller.addTextField { textField in
            textField.text = text
            textField.placeholder = placeholder
            textField.keyboardType = keyboardType
        }
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.action(nil)
            close()
        })
        controller.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.action(controller.textFields?.first?.text)
            close()
        })
        return controller
    }

    private func close() {
        isPresented = false
        controller = nil
    }

}
