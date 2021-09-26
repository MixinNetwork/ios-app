import UIKit

class UnknownURLWindow: BottomSheetView {
    
    @IBOutlet weak var tipLabel: UILabel!
    
    class func instance(url: String) -> UnknownURLWindow {
        let window = Bundle.main.loadNibNamed("UnknownURLWindow", owner: nil, options: nil)?.first as! UnknownURLWindow
        window.tipLabel.text = R.string.localizable.url_unrecognized_tip(url)
        return window
    }
    
    @IBAction func okAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }
    
}
