import UIKit

class AccessPhoneContactHintWindow: BottomSheetView {
    
    @IBOutlet weak var button: RoundedButton!
    
    var action: (() -> Void)?
    
    class func instance() -> AccessPhoneContactHintWindow {
        R.nib.accessPhoneContactHintWindow(owner: self)!
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupController(animated: true)
    }
    
    @IBAction func buttonAction(_ sender: Any) {
        action?()
        dismissPopupController(animated: true)
    }
    
}
