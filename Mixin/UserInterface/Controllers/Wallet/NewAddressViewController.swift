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
    @IBOutlet weak var memoHintTextView: UITextView!
    @IBOutlet weak var continueWrapperView: UIView!
    @IBOutlet weak var memoView: CornerView!

    @IBOutlet weak var opponentImageViewWidthConstraint: ScreenSizeCompatibleLayoutConstraint!
    @IBOutlet weak var continueWrapperBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewBottomConstraint: NSLayoutConstraint!
    
    private var asset: AssetItem!
    private var addressValue: String {
        return addressTextView.text?.trim() ?? ""
    }
    private var labelValue: String {
        return labelTextField.text?.trim() ?? ""
    }
    private var memoValue: String {
        return memoTextView.text?.trim() ?? ""
    }
    private var isLegalAddress: Bool {
        return !addressValue.isEmpty && !labelValue.isEmpty && (noMemo || !memoValue.isEmpty)
    }
    private var successCallback: ((Address) -> Void)?
    private var address: Address?
    private var qrCodeScanningDestination: UIView?
    private var shouldLayoutWithKeyboard = true
    private var noMemo = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addressTextView.delegate = self
        addressTextView.textContainerInset = .zero
        addressTextView.textContainer.lineFragmentPadding = 0
        memoTextView.delegate = self
        memoTextView.textContainerInset = .zero
        memoTextView.textContainer.lineFragmentPadding = 0
        if ScreenSize.current >= .inch6_1 {
            assetView.chainIconWidth = 28
            assetView.chainIconOutlineWidth = 4
        }
        assetView.setIcon(asset: asset)
        if let address = address {
            labelTextField.text = address.label
            addressTextView.text = address.destination
            memoTextView.text = address.tag
            noMemo = address.tag.isEmpty
            checkLabelAndAddressAction(self)
            view.layoutIfNeeded()
            textViewDidChange(addressTextView)
            textViewDidChange(memoTextView)
        }

        memoTextView.placeholder = asset.memoLabel
        updateMemoTips()
    }

    private func updateMemoTips() {
        var hint: String
        var action: String
        if noMemo {
            if asset.isUseTag {
                hint = R.string.localizable.address_memo_add(R.string.localizable.address_add_tag())
                action = R.string.localizable.address_add_tag()
            } else {
                hint = R.string.localizable.address_memo_add(R.string.localizable.address_add_memo())
                action = R.string.localizable.address_add_memo()
            }
            memoView.isHidden = true
        } else {
            if asset.isUseTag {
                hint = R.string.localizable.address_memo_no(R.string.localizable.address_no_tag())
                action = R.string.localizable.address_no_tag()
            } else {
                hint = R.string.localizable.address_memo_no(R.string.localizable.address_no_memo())
                action = R.string.localizable.address_no_memo()
            }
            memoView.isHidden = false
        }

        let nsIntro = hint as NSString
        let fullRange = NSRange(location: 0, length: nsIntro.length)
        let actionRange = nsIntro.range(of: action)
        let attributedText = NSMutableAttributedString(string: hint)
        let paragraphSytle = NSMutableParagraphStyle()
        paragraphSytle.alignment = .left
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .paragraphStyle: paragraphSytle,
            .foregroundColor: UIColor.accessoryText
        ]
        attributedText.setAttributes(attrs, range: fullRange)
        attributedText.addAttributes([NSAttributedString.Key.link: ""], range: actionRange)
        memoHintTextView.attributedText = attributedText
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shouldLayoutWithKeyboard = true

        if labelValue.isEmpty {
            labelTextField.becomeFirstResponder()
        } else if addressValue.isEmpty || noMemo {
            addressTextView.becomeFirstResponder()
        } else {
            memoTextView.becomeFirstResponder()
        }
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let keyboardHeight = view.frame.height - keyboardFrame.origin.y
        if keyboardHeight > 0 {
            continueWrapperBottomConstraint.constant = keyboardHeight
            scrollViewBottomConstraint.constant = keyboardHeight + 72
            view.layoutIfNeeded()

            if !noMemo {
                scrollView.contentOffset.y = scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
            }
        }
    }

    override func keyboardWillChangeFrame(_ notification: Notification) {
        guard shouldLayoutWithKeyboard else {
            return
        }
        super.keyboardWillChangeFrame(notification)
    }
    
    @IBAction func checkLabelAndAddressAction(_ sender: Any) {
        saveButton.isEnabled = isLegalAddress
    }

    @IBAction func scanAddressAction(_ sender: Any) {
        let vc = CameraViewController.instance()
        vc.delegate = self
        vc.scanQrCodeOnly = true
        navigationController?.pushViewController(vc, animated: true)
        qrCodeScanningDestination = addressTextView
    }

    @IBAction func scanMemoAction(_ sender: Any) {
        let vc = CameraViewController.instance()
        vc.delegate = self
        vc.scanQrCodeOnly = true
        navigationController?.pushViewController(vc, animated: true)
        qrCodeScanningDestination = memoTextView
    }
    
    @IBAction func saveAction(_ sender: Any) {
        guard isLegalAddress else {
            return
        }

        let destination = addressValue.suffix(char: ":") ?? addressValue
        shouldLayoutWithKeyboard = false
        let assetId = asset.assetId
        let requestAddress = AddressRequest(assetId: assetId, destination: destination, tag: memoValue, label: labelValue, pin: "")
        AddressWindow.instance().presentPopupControllerAnimated(action: address == nil ? .add : .update, asset: asset, addressRequest: requestAddress, address: nil, dismissCallback: { [weak self] (success) in
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
        noMemo.toggle()
        if noMemo {
            memoTextView.text = ""
        }
        checkLabelAndAddressAction(textView)
        updateMemoTips()
    }
    
    class func instance(asset: AssetItem, address: Address? = nil, successCallback: ((Address) -> Void)? = nil) -> UIViewController {
        let vc = R.storyboard.wallet.new_address()!
        vc.asset = asset
        vc.successCallback = successCallback
        vc.address = address
        return ContainerViewController.instance(viewController: vc, title: address == nil ? Localized.ADDRESS_NEW_TITLE(symbol: asset.symbol) : Localized.ADDRESS_EDIT_TITLE(symbol: asset.symbol))
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
        navigationController?.popViewController(animated: true)
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
