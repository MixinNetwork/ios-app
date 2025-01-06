import UIKit
import MixinServices

class SwapViewController: KeyboardBasedLayoutViewController {
    
    enum AdditionalInfoStyle {
        case info
        case error
    }
    
    @IBOutlet weak var sendView: UIView!
    @IBOutlet weak var sendStackView: UIStackView!
    
    @IBOutlet weak var sendNetworkLabel: UILabel!
    @IBOutlet weak var sendTokenStackView: UIStackView!
    @IBOutlet weak var sendAmountTextField: UITextField!
    @IBOutlet weak var sendLoadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var sendIconView: PlainTokenIconView!
    @IBOutlet weak var sendSymbolLabel: UILabel!
    @IBOutlet weak var sendBalanceLabel: UILabel!
    
    @IBOutlet weak var receiveView: UIView!
    @IBOutlet weak var receiveStackView: UIStackView!
    
    @IBOutlet weak var receiveNetworkLabel: UILabel!
    @IBOutlet weak var receiveTokenStackView: UIStackView!
    @IBOutlet weak var receiveAmountTextField: UITextField!
    @IBOutlet weak var receiveLoadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var receiveIconView: PlainTokenIconView!
    @IBOutlet weak var receiveSymbolLabel: UILabel!
    @IBOutlet weak var receiveBalanceLabel: UILabel!
    
    @IBOutlet weak var footerInfoLabel: UILabel!
    @IBOutlet weak var footerInfoProgressView: CircularProgressView!
    @IBOutlet weak var footerSpacingView: UIView!
    @IBOutlet weak var swapPriceButton: UIButton!
    
    @IBOutlet weak var swapBackgroundView: UIView!
    @IBOutlet weak var swapButton: UIButton!
    
    @IBOutlet weak var reviewButton: RoundedButton!
    @IBOutlet weak var reviewButtonWrapperBottomConstrait: NSLayoutConstraint!
    
    private let swapInputAccessoryView = R.nib.swapInputAccessoryView(withOwner: nil)!
    
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
        sendAmountTextField.inputAccessoryView = swapInputAccessoryView
        sendLoadingIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        receiveView.layer.masksToBounds = true
        receiveView.layer.cornerRadius = 8
        receiveStackView.setCustomSpacing(12, after: receiveTokenStackView)
        receiveLoadingIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        for symbolLabel in [sendSymbolLabel, receiveSymbolLabel] {
            symbolLabel!.setFont(
                scaledFor: .systemFont(ofSize: 16, weight: .medium),
                adjustForContentSize: true
            )
        }
        sendAmountTextField.becomeFirstResponder()
        swapInputAccessoryView.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let keyboardHeight = view.bounds.height - keyboardFrame.origin.y
        reviewButtonWrapperBottomConstrait.constant = keyboardHeight
        view.layoutIfNeeded()
    }
    
    @IBAction func sendAmountEditingChanged(_ sender: Any) {
        
    }
    
    @IBAction func changeSendToken(_ sender: Any) {
        
    }
    
    @IBAction func changeReceiveToken(_ sender: Any) {
        
    }
    
    @IBAction func swapSendingReceiving(_ sender: Any) {
        if let sender = sender as? UIButton, sender === swapButton {
            let animation = CABasicAnimation(keyPath: "transform.rotation")
            animation.fromValue = 0
            animation.toValue = CGFloat.pi
            animation.duration = 0.35
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            swapButton.layer.add(animation, forKey: nil)
        }
    }
    
    @IBAction func swapPrice(_ sender: Any) {
        
    }
    
    @IBAction func review(_ sender: RoundedButton) {
        
    }
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        guard presentedViewController == nil else {
            return
        }
        sendAmountTextField.becomeFirstResponder()
    }
    
    func reportClientOutdated() {
        let alert = UIAlertController(
            title: R.string.localizable.update_mixin(),
            message: R.string.localizable.app_update_tips(Bundle.main.shortVersionString),
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
    
    func prepareForReuse(sender: Any) {
        sendAmountTextField.text = nil
        sendAmountTextField.sendActions(for: .editingChanged)
    }
    
    func inputSendAmount(multiplier: Decimal) {
        
    }
    
}

extension SwapViewController: SwapInputAccessoryView.Delegate {
    
    func swapInputAccessoryView(_ view: SwapInputAccessoryView, didSelectMultiplier multiplier: Decimal) {
        inputSendAmount(multiplier: multiplier)
    }
    
    func swapInputAccessoryViewDidSelectDone(_ view: SwapInputAccessoryView) {
        sendAmountTextField.resignFirstResponder()
    }
    
}

extension SwapViewController {
    
    enum Footer {
        case calculating
        case error(String)
        case price(String)
    }
    
    func setFooter(_ footer: Footer?) {
        switch footer {
        case .calculating:
            footerInfoLabel.textColor = R.color.text_tertiary()
            footerInfoLabel.text = R.string.localizable.calculating()
            footerInfoLabel.isHidden = false
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        case .error(let description):
            footerInfoLabel.textColor = R.color.red()
            footerInfoLabel.text = description
            footerInfoLabel.isHidden = false
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        case .price(let price):
            footerInfoLabel.textColor = R.color.text_tertiary()
            footerInfoLabel.text = price
            footerInfoLabel.isHidden = false
            footerInfoProgressView.isHidden = false
            footerSpacingView.isHidden = false
            swapPriceButton.isHidden = false
        case nil:
            footerInfoLabel.isHidden = true
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        }
    }
    
}
