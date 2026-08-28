import UIKit

final class UnknownURLWindow: UIViewController {
    
    @IBOutlet weak var tipLabel: UILabel!
    
    private let url: URL
    
    init(url: URL) {
        self.url = url
        let nib = R.nib.unknownURLWindow
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tipLabel.text = R.string.localizable.url_unrecognized_hint(url.absoluteString)
    }

    @IBAction func okAction(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func copyAction(_ sender: Any) {
        UIPasteboard.general.string = url.absoluteString
        dismiss(animated: true) {
            showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        }
    }
    
}
