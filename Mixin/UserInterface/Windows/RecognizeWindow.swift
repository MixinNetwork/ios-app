import UIKit

class RecognizeWindow: BottomSheetView {

    @IBOutlet weak var contentTextView: UITextView!

    override func awakeFromNib() {
        super.awakeFromNib()
        contentTextView.delegate = self
    }

    func presentWindow(text: String) {
        contentTextView.text = text
        super.presentPopupControllerAnimated()
    }

    @IBAction func copyAction(_ sender: Any) {
        UIPasteboard.general.string = contentTextView.text
        dismissPopupControllerAnimated()
        UIApplication.showHud(style: .notification, text: Localized.TOAST_COPIED)
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    class func instance() -> RecognizeWindow {
        return Bundle.main.loadNibNamed("RecognizeWindow", owner: nil, options: nil)?.first as! RecognizeWindow
    }
}

extension RecognizeWindow: UITextViewDelegate {

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        dismissPopupControllerAnimated()
        WebWindow.instance(conversationId: "").presentPopupControllerAnimated(url: URL)
        return false
    }

}
