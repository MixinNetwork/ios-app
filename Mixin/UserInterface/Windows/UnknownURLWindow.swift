import UIKit

class UnknownURLWindow: BottomSheetView {
    
    @IBOutlet weak var tipLabel: UILabel!
    
    class func instance(url: URL) -> UnknownURLWindow {
        let window = R.nib.unknownURLWindow(owner: self)!
        window.tipLabel.text = R.string.localizable.url_unrecognized_tip(url.absoluteString)
        return window
    }
    
    @IBAction func okAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }
    
}
