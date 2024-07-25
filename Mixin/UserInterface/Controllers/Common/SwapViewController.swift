import UIKit
import MixinServices

class SwapViewController: KeyboardBasedLayoutViewController {
    
    enum AdditionalInfoStyle {
        case info
        case error
    }
    
    @IBOutlet weak var sendView: UIView!
    @IBOutlet weak var sendStackView: UIStackView!
    
    @IBOutlet weak var sendTitleStackView: UIStackView!
    
    @IBOutlet weak var sendTokenStackView: UIStackView!
    @IBOutlet weak var sendBalanceLabel: UILabel!
    @IBOutlet weak var sendAmountTextField: UITextField!
    @IBOutlet weak var sendLoadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var sendIconView: PlainTokenIconView!
    @IBOutlet weak var sendSymbolLabel: UILabel!
    
    @IBOutlet weak var sendNetworkLabel: UILabel!
    @IBOutlet weak var sendValueLabel: UILabel!
    
    @IBOutlet weak var receiveView: UIView!
    @IBOutlet weak var receiveStackView: UIStackView!
    
    @IBOutlet weak var receiveBalanceLabel: UILabel!
    
    @IBOutlet weak var receiveTokenStackView: UIStackView!
    @IBOutlet weak var receiveAmountTextField: UITextField!
    @IBOutlet weak var receiveLoadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var receiveIconView: PlainTokenIconView!
    @IBOutlet weak var receiveSymbolLabel: UILabel!
    
    @IBOutlet weak var receiveInfoStackView: UIStackView!
    @IBOutlet weak var receiveNetworkLabel: UILabel!
    @IBOutlet weak var receiveValueLabel: UILabel!
    
    @IBOutlet weak var receiveSeparatorLineView: UIView!
    
    @IBOutlet weak var receiveAdditionalInfoLabel: UILabel!
    
    @IBOutlet weak var swapBackgroundView: UIView!
    @IBOutlet weak var swapButton: UIButton!
    
    @IBOutlet weak var reviewButton: RoundedButton!
    @IBOutlet weak var reviewButtonWrapperBottomConstrait: NSLayoutConstraint!
    
    init() {
        let nib = R.nib.swapView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sendView.layer.masksToBounds = true
        sendView.layer.cornerRadius = 8
        sendStackView.setCustomSpacing(12, after: sendTokenStackView)
        sendLoadingIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        receiveView.layer.masksToBounds = true
        receiveView.layer.cornerRadius = 8
        receiveStackView.setCustomSpacing(12, after: receiveTokenStackView)
        receiveStackView.setCustomSpacing(16, after: receiveInfoStackView)
        receiveStackView.setCustomSpacing(16, after: receiveSeparatorLineView)
        receiveLoadingIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        sendAmountTextField.becomeFirstResponder()
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let keyboardHeight = view.bounds.height - keyboardFrame.origin.y
        reviewButtonWrapperBottomConstrait.constant = keyboardHeight
        view.layoutIfNeeded()
    }
    
    @IBAction func sendAmountEditingChanged(_ sender: UITextField) {
        
    }
    
    @IBAction func changeSendToken(_ sender: Any) {
        
    }
    
    @IBAction func changeReceiveToken(_ sender: Any) {
        
    }
    
    @IBAction func swapSendingReceiving(_ sender: Any) {
        
    }
    
    @IBAction func review(_ sender: RoundedButton) {
        
    }
    
    func reportAdditionalInfo(style: AdditionalInfoStyle, text: String) {
        switch style {
        case .info:
            receiveAdditionalInfoLabel.textColor = R.color.text_tertiary()
        case .error:
            receiveAdditionalInfoLabel.textColor = R.color.red()
        }
        receiveAdditionalInfoLabel.text = text
    }
    
    func reportClientOutdated() {
        let alert = UIAlertController(
            title: R.string.localizable.update_mixin(),
            message: R.string.localizable.app_update_tips(Bundle.main.shortVersion),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: R.string.localizable.update(), style: .default, handler: { _ in
            self.navigationController?.popViewController(animated: false)
            UIApplication.shared.openAppStorePage()
        }))
        alert.addAction(UIAlertAction(title: R.string.localizable.later(), style: .cancel, handler: { _ in
            self.navigationController?.popViewController(animated: true)
        }))
        self.present(alert, animated: true)
    }
    
}
