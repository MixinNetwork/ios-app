import UIKit

final class AccessPhoneContactHintWindow: UIViewController {
    
    @IBOutlet weak var button: RoundedButton!
    
    var action: (() -> Void)?
    private let buttonTitle: String?
    
    init(buttonTitle: String? = nil, action: (() -> Void)? = nil) {
        self.buttonTitle = buttonTitle
        self.action = action
        let nib = R.nib.accessPhoneContactHintWindow
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let buttonTitle = buttonTitle {
            button.setTitle(buttonTitle, for: .normal)
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func buttonAction(_ sender: Any) {
        let action = self.action
        dismiss(animated: true) {
            action?()
        }
    }
    
}
