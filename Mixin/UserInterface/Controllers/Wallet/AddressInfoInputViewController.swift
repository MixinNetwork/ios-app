import UIKit
import MixinServices

final class AddressInfoInputViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var nextButton: StyledButton!
    
    @IBOutlet weak var stackViewBottomConstraint: NSLayoutConstraint!
    
    private let token: TokenItem
    private let intent: Intent
    private let inputContent: InputContent
    private let progress: UserInteractionProgress?
    private let headerView = R.nib.addressInfoInputHeaderView(withOwner: nil)!
    
    private lazy var tagRegex = try? NSRegularExpression(pattern: "^[0-9]+$")
    
    private init(token: TokenItem, intent: Intent, inputContent: InputContent) {
        self.token = token
        self.intent = intent
        self.inputContent = inputContent
        switch intent {
        case .newAddress:
            switch token.memoPossibility {
            case .positive, .possible:
                switch inputContent {
                case .destination:
                    self.progress = UserInteractionProgress(currentStep: 1, totalStepCount: 3)
                case .memo, .tag:
                    self.progress = UserInteractionProgress(currentStep: 2, totalStepCount: 3)
                case .label:
                    self.progress = UserInteractionProgress(currentStep: 3, totalStepCount: 3)
                }
            case .negative:
                switch inputContent {
                case .destination:
                    self.progress = UserInteractionProgress(currentStep: 1, totalStepCount: 2)
                case .memo, .tag:
                    assertionFailure("No memo/tag for negative possiblity")
                    self.progress = nil
                case .label:
                    self.progress = UserInteractionProgress(currentStep: 2, totalStepCount: 2)
                }
            }
        case .oneTimeWithdraw:
            switch inputContent {
            case .destination:
                assertionFailure("Destination should be input in TokenReceiverViewController")
                self.progress = nil
            case .memo, .tag:
                switch token.memoPossibility {
                case .positive, .possible:
                    self.progress = UserInteractionProgress(currentStep: 2, totalStepCount: 3)
                case .negative:
                    assertionFailure("No memo/tag for negative possiblity")
                    self.progress = nil
                }
            case .label:
                assertionFailure("No label for oneTimeWithdraw")
                self.progress = nil
            }
        }
        let nib = R.nib.addressInfoInputView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    static func newAddress(token: TokenItem) -> AddressInfoInputViewController {
        AddressInfoInputViewController(token: token, intent: .newAddress, inputContent: .destination)
    }
    
    // Returns non-nil result if memo/tag is needed
    static func oneTimeWithdraw(token: TokenItem, destination: String) -> AddressInfoInputViewController? {
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
        
        let title = switch intent {
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
        if let progress {
            navigationItem.titleView = NavigationTitleView(title: title, subtitle: progress.description)
        } else {
            self.title = title
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
            break
        case let .memo(destination), let .tag(destination), let .label(destination, _):
            headerView.addAddressView { label in
                label.text = destination
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
                if !content.isEmpty {
                    let destination = self.destination(bip21Unchecked: content)
                    let next = AddressInfoInputViewController(
                        token: token,
                        intent: intent,
                        inputContent: InputContent(token: token, destination: destination)
                    )
                    navigationController?.pushViewController(next, animated: true)
                }
            case let .tag(destination):
                if isTagValid(content) {
                    fallthrough
                } else {
                    reportError(description: R.string.localizable.invalid_tag_description())
                }
            case let .memo(destination):
                let next = AddressInfoInputViewController(
                    token: token,
                    intent: intent,
                    inputContent: .label(destination: destination, tag: content)
                )
                navigationController?.pushViewController(next, animated: true)
            case let .label(destination, tag):
                if !content.isEmpty {
                    saveNewAddress(destination: destination, tag: tag, label: content)
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
        case .destination, .tag, .label:
            nextButton.isEnabled = !content.isEmpty
        case .memo:
            break
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
        case label(destination: String, tag: String?)
        
        init(token: TokenItem, destination: String) {
            switch token.memoPossibility {
            case .positive, .possible:
                if token.usesTag {
                    self = .tag(destination: destination)
                } else {
                    self = .memo(destination: destination)
                }
            case .negative:
                self = .label(destination: destination, tag: nil)
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
    
    private func saveNewAddress(destination: String, tag: String?, label: String) {
        let preview = EditAddressPreviewViewController(
            token: token,
            label: label,
            destination: destination,
            tag: tag ?? "",
            action: .add
        )
        preview.onSavingSuccess = {
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
        OneTimeAddressValidator.validate(
            assetID: token.assetID,
            destination: destination,
            tag: tag
        ) { [weak self] (address) in
            guard let self else {
                return
            }
            self.nextButton.isBusy = false
            let next = WithdrawInputAmountViewController(
                tokenItem: self.token,
                destination: .temporary(address),
                progress: .init(currentStep: 3, totalStepCount: 3)
            )
            self.navigationController?.pushViewController(next, animated: true)
        } onFailure: { [weak self] error in
            guard let self else {
                return
            }
            self.nextButton.isBusy = false
            self.reportError(description: error.localizedDescription)
        }
    }
    
}
