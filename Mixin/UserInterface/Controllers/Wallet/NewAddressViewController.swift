import UIKit
import MixinServices

class NewAddressViewController: KeyboardBasedLayoutViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var labelTextField: UITextField!
    @IBOutlet weak var addressTextView: PlaceholderTextView!
    @IBOutlet weak var memoTextView: PlaceholderTextView!
    @IBOutlet weak var memoScanButton: UIButton!
    @IBOutlet weak var saveButton: RoundedButton!
    @IBOutlet weak var assetView: AssetIconView!
    @IBOutlet weak var memoHintWrapperView: UIView!
    @IBOutlet weak var memoHintTextView: UITextView!
    @IBOutlet weak var continueWrapperView: UIView!
    @IBOutlet weak var memoView: CornerView!

    @IBOutlet weak var continueWrapperBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewBottomConstraint: NSLayoutConstraint!
    
    private var asset: TokenItem! {
        didSet {
            if let chain = asset.chain {
                memoPossibility = WithdrawalMemoPossibility(rawValue: chain.withdrawalMemoPossibility) ?? .possible
            } else {
                memoPossibility = .possible
            }
        }
    }
    
    private var successCallback: ((Address) -> Void)?
    private var qrCodeScanningDestination: UIView?
    private var shouldLayoutWithKeyboard = true
    private var memoPossibility: WithdrawalMemoPossibility = .possible
    
    private var addressValue: String {
        return addressTextView.text?.trim() ?? ""
    }
    
    private var labelValue: String {
        return labelTextField.text?.trim() ?? ""
    }
    
    private var memoValue: String {
        return memoTextView.text?.trim() ?? ""
    }
    
    private var areInputsValid: Bool {
        guard !labelValue.isEmpty else {
            return false
        }
        guard !addressValue.isEmpty else {
            return false
        }
        if memoPossibility.isRequired {
            return !memoValue.isEmpty
        } else {
            return true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addressTextView.delegate = self
        addressTextView.textContainerInset = .zero
        addressTextView.textContainer.lineFragmentPadding = 0
        memoTextView.delegate = self
        memoTextView.textContainerInset = .zero
        memoTextView.textContainer.lineFragmentPadding = 0
        if ScreenHeight.current >= .extraLong {
            assetView.chainIconWidth = 28
            assetView.chainIconOutlineWidth = 4
        }
        assetView.setIcon(token: asset)
        memoTextView.placeholder = asset.memoLabel
        
        switch memoPossibility {
        case .positive:
            memoView.isHidden = false
            memoHintWrapperView.isHidden = true
        case .negative:
            memoView.isHidden = true
            memoHintWrapperView.isHidden = true
        case .possible:
            memoView.isHidden = true
            memoHintWrapperView.isHidden = false
            updateMemoHint()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shouldLayoutWithKeyboard = true

        if labelValue.isEmpty {
            labelTextField.becomeFirstResponder()
        } else if addressValue.isEmpty || !memoPossibility.isRequired {
            addressTextView.becomeFirstResponder()
        } else {
            memoTextView.becomeFirstResponder()
        }
    }
    
    override func layout(for keyboardFrame: CGRect) {
        guard keyboardFrame.height > 0 else {
            return
        }
        continueWrapperBottomConstraint.constant = keyboardFrame.height
        scrollViewBottomConstraint.constant = keyboardFrame.height + 72
        view.layoutIfNeeded()
    }

    override func keyboardWillChangeFrame(_ notification: Notification) {
        guard shouldLayoutWithKeyboard else {
            return
        }
        super.keyboardWillChangeFrame(notification)
    }
    
    @IBAction func checkLabelAndAddressAction(_ sender: Any) {
        saveButton.isEnabled = areInputsValid
    }

    @IBAction func scanAddressAction(_ sender: Any) {
        let vc = CameraViewController.instance()
        vc.delegate = self
        vc.asQrCodeScanner = true
        navigationController?.pushViewController(vc, animated: true)
        qrCodeScanningDestination = addressTextView
    }

    @IBAction func scanMemoAction(_ sender: Any) {
        let vc = CameraViewController.instance()
        vc.delegate = self
        vc.asQrCodeScanner = true
        navigationController?.pushViewController(vc, animated: true)
        qrCodeScanningDestination = memoTextView
    }
    
    @IBAction func saveAction(_ sender: Any) {
        guard areInputsValid else {
            return
        }
        let assetId = asset.assetId
        var destination = addressValue
        if asset.isBitcoinChain {
            if destination.lowercased().hasPrefix("bitcoin:"), let address = URLComponents(string: destination)?.path {
                destination = address
            }
        }
        let tag = memoView.isHidden ? "" : memoValue
        let requestAddress = AddressRequest(assetId: assetId, destination: destination, tag: tag, label: labelValue, pin: "")
        shouldLayoutWithKeyboard = false
        AddressWindow.instance().presentPopupControllerAnimated(action: .add, asset: asset, addressRequest: requestAddress, address: nil, dismissCallback: { [weak self] (success) in
            guard let weakSelf = self else {
                return
            }
            if success {
                weakSelf.navigationController?.popViewController(animated: true)
            } else {
                weakSelf.shouldLayoutWithKeyboard = true
                weakSelf.labelTextField.becomeFirstResponder()
            }
        })
    }
    
    @IBAction func memoHintTapAction(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else {
            return
        }
        let point = recognizer.location(in: memoHintTextView)
        guard let position = memoHintTextView.closestPosition(to: point) else {
            return
        }
        guard let range = memoHintTextView.tokenizer.rangeEnclosingPosition(position, with: .character, inDirection: .layout(.left)) else {
            return
        }
        let startIndex = memoHintTextView.offset(from: memoHintTextView.beginningOfDocument, to: range.start)
        let attr = memoHintTextView.attributedText.attribute(.link, at: startIndex, effectiveRange: nil)
        guard attr != nil else {
            return
        }
        memoView.isHidden.toggle()
        updateMemoHint()
        checkLabelAndAddressAction(textView)
    }
    
    class func instance(asset: TokenItem, successCallback: ((Address) -> Void)? = nil) -> UIViewController {
        let vc = R.storyboard.wallet.new_address()!
        vc.asset = asset
        vc.successCallback = successCallback
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.withdrawal_addr_new(asset.symbol))
    }
    
    private func updateMemoHint() {
        let action: String
        let hint: String
        if memoView.isHidden {
            if asset.usesTag {
                action = R.string.localizable.add_tag()
            } else {
                action = R.string.localizable.add_memo()
            }
            hint = R.string.localizable.withdrawal_addr_no_memo_or_tag(action)
        } else {
            if asset.usesTag {
                action = R.string.localizable.no_tag()
            } else {
                action = R.string.localizable.withdrawal_no_memo()
            }
            hint = R.string.localizable.withdrawal_addr_has_memo_or_tag(action)
        }
        let nsHint = hint as NSString
        let fullRange = NSRange(location: 0, length: nsHint.length)
        let attributedText = NSMutableAttributedString(string: hint)
        let paragraphSytle = NSMutableParagraphStyle()
        paragraphSytle.alignment = .left
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .paragraphStyle: paragraphSytle,
            .foregroundColor: UIColor.accessoryText
        ]
        attributedText.setAttributes(attrs, range: fullRange)
        let actionRange = nsHint.range(of: action)
        if actionRange.location != NSNotFound && actionRange.length != 0 {
            attributedText.addAttributes([NSAttributedString.Key.link: ""], range: actionRange)
        }
        memoHintTextView.attributedText = attributedText
    }
    
}

extension NewAddressViewController: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return text != "\n"
    }
    
    func textViewDidChange(_ textView: UITextView) {
        checkLabelAndAddressAction(textView)
        view.layoutIfNeeded()
        let sizeToFit = CGSize(width: textView.bounds.width,
                               height: UIView.layoutFittingExpandedSize.height)
        let contentSize = textView.sizeThatFits(sizeToFit)
        textView.isScrollEnabled = contentSize.height > textView.frame.height
    }
    
}

extension NewAddressViewController: CameraViewControllerDelegate {
    
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool {
        if qrCodeScanningDestination == addressTextView {
            addressTextView.text = standarizedAddress(from: string) ?? string
            textViewDidChange(addressTextView)
        } else if qrCodeScanningDestination == memoTextView {
            memoTextView.text = string
            textViewDidChange(memoTextView)
        }
        qrCodeScanningDestination = nil
        return false
    }
    
}

extension NewAddressViewController {
    
    private func standarizedAddress(from str: String) -> String? {
        guard str.hasPrefix("iban:XE") || str.hasPrefix("IBAN:XE") else {
            return str
        }
        guard str.count >= 20 else {
            return nil
        }
        
        let endIndex = str.firstIndex(of: "?") ?? str.endIndex
        let accountIdentifier = str[str.index(str.startIndex, offsetBy: 9)..<endIndex]
        
        guard let address = accountIdentifier.lowercased().base36to16() else {
            return nil
        }
        return "0x\(address)"
    }
    
}

private extension String {
    
    private static let base36Alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"
    
    private static var base36AlphabetMap: [Character: Int] = {
        var reverseLookup = [Character: Int]()
        for characterIndex in 0..<String.base36Alphabet.count {
            let character = base36Alphabet[base36Alphabet.index(base36Alphabet.startIndex, offsetBy: characterIndex)]
            reverseLookup[character] = characterIndex
        }
        return reverseLookup
    }()
    
    func base36to16() -> String? {
        var bytes = [Int]()
        for character in self {
            guard var carry = String.base36AlphabetMap[character] else {
                return nil
            }
            
            for byteIndex in 0..<bytes.count {
                carry += bytes[byteIndex] * 36
                bytes[byteIndex] = carry & 0xff
                carry >>= 8
            }
            
            while carry > 0 {
                bytes.append(carry & 0xff)
                carry >>= 8
            }
        }
        return bytes.reversed().map { String(format: "%02hhx", $0) }.joined()
    }
    
}
