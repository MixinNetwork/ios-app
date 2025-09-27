import UIKit

final class MnemonicTextField: InsetTextField {
    
    protocol DeleteDelegate: AnyObject {
        func mnemonicTextField(_ textField: MnemonicTextField, didDeleteBackwardFrom textBefore: String?, to textAfter: String?)
    }
    
    weak var deleteDelegate: DeleteDelegate?
    
    override func deleteBackward() {
        let textBefore = self.text
        super.deleteBackward()
        let textAfter = self.text
        deleteDelegate?.mnemonicTextField(self, didDeleteBackwardFrom: textBefore, to: textAfter)
    }
    
}
