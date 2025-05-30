import UIKit
import MixinServices

class SwapViewController: KeyboardBasedLayoutViewController {
    
    enum AdditionalInfoStyle {
        case info
        case error
    }
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    
    @IBOutlet weak var sendView: UIView!
    @IBOutlet weak var sendStackView: UIStackView!
    
    @IBOutlet weak var sendNetworkLabel: UILabel!
    @IBOutlet weak var sendTokenStackView: UIStackView!
    @IBOutlet weak var sendAmountTextField: UITextField!
    @IBOutlet weak var sendLoadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var sendIconView: BadgeIconView!
    @IBOutlet weak var sendSymbolLabel: UILabel!
    @IBOutlet weak var sendFooterStackView: UIStackView!
    @IBOutlet weak var depositSendTokenButton: BusyButton!
    @IBOutlet weak var sendBalanceButton: UIButton!
    
    @IBOutlet weak var receiveView: UIView!
    @IBOutlet weak var receiveStackView: UIStackView!
    
    @IBOutlet weak var receiveNetworkLabel: UILabel!
    @IBOutlet weak var receiveTokenStackView: UIStackView!
    @IBOutlet weak var receiveAmountTextField: UITextField!
    @IBOutlet weak var receiveLoadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var receiveIconView: BadgeIconView!
    @IBOutlet weak var receiveSymbolLabel: UILabel!
    @IBOutlet weak var receiveBalanceLabel: UILabel!
    
    @IBOutlet weak var footerInfoButton: UIButton!
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
        sendStackView.setCustomSpacing(0, after: sendTokenStackView)
        sendAmountTextField.inputAccessoryView = swapInputAccessoryView
        sendLoadingIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        receiveView.layer.masksToBounds = true
        receiveView.layer.cornerRadius = 8
        receiveStackView.setCustomSpacing(10, after: receiveTokenStackView)
        receiveLoadingIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        for symbolLabel in [sendSymbolLabel, receiveSymbolLabel] {
            symbolLabel!.setFont(
                scaledFor: .systemFont(ofSize: 16, weight: .medium),
                adjustForContentSize: true
            )
        }
        sendAmountTextField.becomeFirstResponder()
        swapInputAccessoryView.delegate = self
        footerInfoButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .regular),
            adjustForContentSize: true
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
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
    
    @IBAction func depositSendToken(_ sender: Any) {
        
    }
    
    @IBAction func inputSendTokenBalance(_ sender: Any) {
        inputSendAmount(multiplier: 1)
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
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        reviewButtonWrapperBottomConstrait.constant = 0
        view.layoutIfNeeded()
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
            footerInfoButton.setTitleColor(R.color.text_tertiary(), for: .normal)
            footerInfoButton.setTitle(R.string.localizable.calculating(), for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        case .error(let description):
            footerInfoButton.setTitleColor(R.color.red(), for: .normal)
            footerInfoButton.setTitle(description, for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        case .price(let price):
            footerInfoButton.setTitleColor(R.color.text_tertiary(), for: .normal)
            footerInfoButton.setTitle(price, for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = false
            footerSpacingView.isHidden = false
            swapPriceButton.isHidden = false
        case nil:
            footerInfoButton.isHidden = true
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        }
        let reviewButtonFrame = reviewButton.convert(reviewButton.bounds, to: view)
        let contentViewFrame = contentView.convert(contentView.bounds, to: view)
        scrollView.alwaysBounceVertical = reviewButtonFrame.intersects(contentViewFrame)
    }
    
}
