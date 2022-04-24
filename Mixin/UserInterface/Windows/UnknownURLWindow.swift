import UIKit

class UnknownURLWindow: BottomSheetView {
    
    @IBOutlet weak var tipLabel: UILabel!
    
    private var urlString: String!
    
    class func instance() -> UnknownURLWindow {
        return R.nib.unknownURLWindow(owner: self)!
    }
    
    func render(url: URL) -> BottomSheetView {
        tipLabel.text = R.string.localizable.url_unrecognized_hint(url.absoluteString)
        urlString = url.absoluteString
        return self
    }

    @IBAction func okAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }
    
    @IBAction func copyAction(_ sender: Any) {
        UIPasteboard.general.string = urlString
        dismissPopupControllerAnimated()
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}
