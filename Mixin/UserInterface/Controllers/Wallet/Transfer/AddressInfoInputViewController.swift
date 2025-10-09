import UIKit
import MixinServices

final class AddressInfoInputViewController: KeyboardBasedLayoutViewController {
    
    typealias ValuableOnChainToken = any ValuableToken & OnChainToken
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var nextButton: StyledButton!
    
    @IBOutlet weak var stackViewBottomConstraint: NSLayoutConstraint!
    
    private let token: ValuableOnChainToken
    private let intent: Intent
    private let inputContent: InputContent
    private let headerView = R.nib.addressInfoInputHeaderView(withOwner: nil)!
    
    private lazy var tagRegex = try? NSRegularExpression(pattern: "^[0-9]+$")
    
    private init(token: ValuableOnChainToken, intent: Intent, inputContent: InputContent) {
        self.token = token
        self.intent = intent
        self.inputContent = inputContent
        let nib = R.nib.addressInfoInputView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    static func newAddress(token: ValuableOnChainToken) -> AddressInfoInputViewController {
        AddressInfoInputViewController(token: token, intent: .newAddress, inputContent: .destination)
    }
    
    // Returns non-nil result if memo/tag is needed
    static func oneTimeWithdraw(token: MixinTokenItem, destination: String) -> AddressInfoInputViewController? {
        let content = InputContent(token: token, destination: destination)
        switch content {
        case .destination, .label:
            return nil
        case .memo, .tag:
            return AddressInfoInputViewController(
                token: token,
                intent: .oneTimeWithdraw,
                inputContent: content
            )
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = switch intent {
        case .newAddress:
            switch inputContent {
            case .destination:
                R.string.localizable.address()
            case .memo:
                R.string.localizable.memo()
            case .tag:
                R.string.localizable.tag()
            case .label:
                R.string.localizable.label()
            }
        case .oneTimeWithdraw:
            R.string.localizable.send()
        }
        
        scrollView.addSubview(headerView)
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        headerView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
        headerView.load(token: token)
        headerView.delegate = self
        headerView.textView.becomeFirstResponder()
        switch inputContent {
        case .destination:
            reporter.report(event: .addAddressStart)
        case let .memo(destination), let .tag(destination):
            reporter.report(event: .addAddressMemo)
            headerView.addAddressView { label in
                label.text = destination
            }
        case let .label(address):
            reporter.report(event: .addAddressLabel)
            headerView.addAddressView { label in
                label.text = address.destination
            }
        }
        switch inputContent {
        case .destination:
            headerView.inputPlaceholder = R.string.localizable.hint_address()
            nextButton.isEnabled = false
        case .memo:
            headerView.inputPlaceholder = R.string.localizable.memo_placeholder()
            nextButton.isEnabled = true
        case .tag:
            headerView.inputPlaceholder = R.string.localizable.tag_placeholder()
            nextButton.isEnabled = true
        case .label:
            headerView.inputPlaceholder = R.string.localizable.withdrawal_label_placeholder()
            nextButton.isEnabled = false
        }
        nextButton.setTitle(R.string.localizable.next(), for: .normal)
        nextButton.style = .filled
        nextButton.applyDefaultContentInsets()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    override func layout(for keyboardFrame: CGRect) {
        stackViewBottomConstraint.constant = keyboardFrame.height
        view.layoutIfNeeded()
    }
    
    @IBAction func goNext(_ sender: Any) {
        let content = headerView.trimmedContent
        switch intent {
        case .newAddress:
            switch inputContent {
            case .destination:
                let destination = self.destination(bip21Unchecked: content)
                if !destination.isEmpty {
                    let nextInputContent = InputContent(token: token, destination: destination)
                    switch nextInputContent {
                    case .destination:
                        // Impossible, user just input the destination
                        break
                    case .memo, .tag:
                        nextButton.isBusy = true
                        ExternalAPI.checkAddressSkippingTag(
                            chainID: token.chainID,
                            assetID: token.assetID,
                            destination: destination
                        ) { [weak self] result in
                            switch result {
                            case .success(let response):
                                guard let self else {
                                    return
                                }
                                guard destination.lowercased() == response.destination.lowercased() else {
                                    fallthrough
                                }
                                self.nextButton.isBusy = false
                                self.pushNext(inputContent: nextInputContent)
                            case .failure:
                                guard let self else {
                                    return
                                }
                                self.nextButton.isBusy = false
                                self.reportError(description: R.string.localizable.invalid_address())
                            }
                        }
                    case let .label(address):
                        nextButton.isBusy = true
                        AddressValidator.validate(
                            chainID: token.chainID,
                            assetID: token.assetID,
                            destination: address.destination,
                            tag: address.tag
                        ) { [weak self] destination in
                            guard let self else {
                                return
                            }
                            self.nextButton.isBusy = false
                            self.pushNext(inputContent: .label(destination.withdrawable))
                        } onFailure: { [weak self] error in
                            guard let self else {
                                return
                            }
                            self.nextButton.isBusy = false
                            self.reportError(description: R.string.localizable.invalid_address())
                        }
                    }
                }
            case let .tag(destination):
                if isTagValid(content) {
                    fallthrough
                } else {
                    reportError(description: R.string.localizable.invalid_tag_description())
                }
            case let .memo(destination):
                nextButton.isBusy = true
                AddressValidator.validate(
                    chainID: token.chainID,
                    assetID: token.assetID,
                    destination: destination,
                    tag: content
                ) { [weak self] destination in
                    guard let self else {
                        return
                    }
                    self.nextButton.isBusy = false
                    self.pushNext(inputContent: .label(destination.withdrawable))
                } onFailure: { [weak self] error in
                    guard let self else {
                        return
                    }
                    self.nextButton.isBusy = false
                    self.reportError(description: R.string.localizable.invalid_address())
                }
            case let .label(address):
                if !content.isEmpty {
                    saveNewAddress(address: address, label: content)
                }
            }
        case .oneTimeWithdraw:
            switch inputContent {
            case .destination:
                assertionFailure("Only input memo/tag with this view controller when performing One-Time-Withdraw")
            case let .tag(destination):
                if isTagValid(content) {
                    fallthrough
                } else {
                    reportError(description: R.string.localizable.invalid_tag_description())
                }
            case let .memo(destination):
                withdraw(destination: destination, tag: content)
            case .label:
                assertionFailure("Only input memo/tag with this view controller when performing One-Time-Withdraw")
            }
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        stackViewBottomConstraint.constant = 0
        view.layoutIfNeeded()
    }
    
    private func pushNext(inputContent: InputContent) {
        let next = AddressInfoInputViewController(
            token: token,
            intent: intent,
            inputContent: inputContent
        )
        navigationController?.pushViewController(next, animated: true)
    }
    
}

extension AddressInfoInputViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension AddressInfoInputViewController: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        text != "\n"
    }
    
}

extension AddressInfoInputViewController: AddressInfoInputHeaderView.Delegate {
    
    func addressInfoInputHeaderView(_ headerView: AddressInfoInputHeaderView, didUpdateContent content: String) {
        errorDescriptionLabel.isHidden = true
        switch inputContent {
        case .destination, .label:
            nextButton.isEnabled = !content.isEmpty
        case .memo, .tag:
            nextButton.isEnabled = true
        }
    }
    
    func addressInfoInputHeaderViewWantsToScanContent(_ headerView: AddressInfoInputHeaderView) {
        let scanner = CameraViewController.instance()
        scanner.asQrCodeScanner = true
        scanner.delegate = self
        navigationController?.pushViewController(scanner, animated: true)
    }
    
}

extension AddressInfoInputViewController: CameraViewControllerDelegate {
    
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool {
        switch inputContent {
        case .destination:
            let destination = IBANAddress(string: string)?.standarizedAddress ?? string
            headerView.setContent(destination)
        case .memo, .tag, .label:
            headerView.setContent(string)
        }
        return false
    }
    
}

extension AddressInfoInputViewController {
    
    private enum Intent {
        case newAddress
        case oneTimeWithdraw
    }
    
    private enum InputContent {
        
        case destination
        case memo(destination: String)
        case tag(destination: String)
        case label(WithdrawableAddress)
        
        init(token: any OnChainToken, destination: String) {
            switch token.memoPossibility {
            case .positive, .possible:
                if token.usesTag {
                    self = .tag(destination: destination)
                } else {
                    self = .memo(destination: destination)
                }
            case .negative:
                let address = TemporaryAddress(destination: destination, tag: "")
                self = .label(address)
            }
        }
        
    }
    
    private func destination(bip21Unchecked destination: String) -> String {
        if token.chainID == ChainID.bitcoin, let uri = BIP21(string: destination) {
            uri.destination
        } else {
            destination
        }
    }
    
    private func isTagValid(_ tag: String) -> Bool {
        let fullRange = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        if let tagRegex,
           tagRegex.rangeOfFirstMatch(in: tag, range: fullRange) == fullRange,
           let number = Decimal(string: tag, locale: .enUSPOSIX),
           number != 0
        {
            return true
        } else {
            return false
        }
    }
    
    private func reportError(description: String) {
        errorDescriptionLabel.text = description
        errorDescriptionLabel.isHidden = false
        nextButton.isEnabled = false
    }
    
    private func saveNewAddress(address: any WithdrawableAddress, label: String) {
        let preview = EditAddressPreviewViewController(
            token: token,
            label: label,
            destination: address.destination,
            tag: address.tag,
            action: .add
        )
        preview.onSavingSuccess = {
            reporter.report(event: .addAddressEnd)
            guard let navigationController = self.navigationController else {
                return
            }
            var viewControllers = navigationController.viewControllers
            while viewControllers.last is AddressInfoInputViewController {
                viewControllers.removeLast()
            }
            navigationController.setViewControllers(viewControllers, animated: false)
        }
        present(preview, animated: true)
    }
    
    private func withdraw(destination: String, tag: String) {
        nextButton.isBusy = true
        let destination = self.destination(bip21Unchecked: destination)
        AddressValidator.validate(
            chainID: token.chainID,
            assetID: token.assetID,
            destination: destination,
            tag: tag
        ) { [weak self, token] (destination) in
            guard let self else {
                return
            }
            self.nextButton.isBusy = false
            if let token = token as? MixinTokenItem {
                let next = WithdrawInputAmountViewController(tokenItem: token, destination: destination)
                self.navigationController?.pushViewController(next, animated: true)
            }
        } onFailure: { [weak self] error in
            guard let self else {
                return
            }
            self.nextButton.isBusy = false
            self.reportError(description: error.localizedDescription)
        }
    }
    
}
