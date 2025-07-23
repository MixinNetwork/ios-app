import UIKit
import MixinServices

class AddWalletInputOnChainInfoViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var networkSelectorBackgroundView: UIView!
    @IBOutlet weak var networkTitleLabel: UILabel!
    @IBOutlet weak var networkNameLabel: UILabel!
    @IBOutlet weak var selectNetworkButton: MenuTriggerButton!
    @IBOutlet weak var inputBackgroundView: UIView!
    @IBOutlet weak var inputTextView: UITextView!
    @IBOutlet weak var inputPlaceholderLabel: InsetLabel!
    @IBOutlet weak var deleteInputButton: UIButton!
    @IBOutlet weak var pasteInputButton: UIButton!
    @IBOutlet weak var scanInputButton: UIButton!
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var continueButton: ConfigurationBasedBusyButton!
    
    private weak var contentHeightConstraint: NSLayoutConstraint!
    
    private(set) var selectedChain: Web3Chain = .ethereum {
        didSet {
            reloadViews(chain: selectedChain)
            detectInput()
        }
    }
    
    init() {
        let nib = R.nib.addWalletInputOnChainInfoView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        let contentLayoutGuide = UILayoutGuide()
        view.addLayoutGuide(contentLayoutGuide)
        contentLayoutGuide.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }
        contentHeightConstraint = contentView.heightAnchor.constraint(equalTo: contentLayoutGuide.heightAnchor, multiplier: 1)
        contentHeightConstraint.isActive = true
        
        for view: UIView in [networkSelectorBackgroundView, inputBackgroundView] {
            view.layer.cornerRadius = 8
            view.layer.masksToBounds = true
        }
        networkTitleLabel.text = R.string.localizable.network()
        selectNetworkButton.showsMenuAsPrimaryAction = true
        reloadViews(chain: selectedChain)
        inputTextView.textContainerInset = .zero
        inputTextView.textContainer.lineFragmentPadding = 0
        inputTextView.font = UIFontMetrics.default.scaledFont(
            for: .monospacedSystemFont(ofSize: 16, weight: .regular)
        )
        errorDescriptionLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        continueButton.titleLabel?.adjustsFontForContentSizeCategory = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rearrangeInputButtons(_:)),
            name: UITextView.textDidChangeNotification,
            object: inputTextView
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(layoutContentByKeyboard(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(layoutContentByKeyboard(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @IBAction func deleteInput(_ sender: Any) {
        inputTextView.text = ""
        rearrangeInputButtons(sender)
        detectInput()
    }
    
    @IBAction func pasteInput(_ sender: Any) {
        inputTextView.text = UIPasteboard.general.string
        rearrangeInputButtons(sender)
        detectInput()
    }
    
    @IBAction func scanInput(_ sender: Any) {
        let scanner = CameraViewController.instance()
        scanner.asQrCodeScanner = true
        scanner.delegate = self
        navigationController?.pushViewController(scanner, animated: true)
    }
    
    @IBAction func continueToNext(_ sender: Any) {
        
    }
    
    func detectInput() {
        
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "input_private_key"])
    }
    
    @objc private func rearrangeInputButtons(_ sender: Any) {
        if inputTextView.text.isEmpty {
            deleteInputButton.isHidden = true
            pasteInputButton.isHidden = false
            scanInputButton.isHidden = false
        } else {
            deleteInputButton.isHidden = false
            pasteInputButton.isHidden = true
            scanInputButton.isHidden = true
        }
    }
    
    @objc private func layoutContentByKeyboard(_ notification: Notification) {
        switch notification.name {
        case UIResponder.keyboardWillShowNotification:
            contentHeightConstraint.priority = .defaultHigh
        case UIResponder.keyboardWillHideNotification:
            contentHeightConstraint.priority = .defaultLow
        default:
            return
        }
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            options: .overdampedCurve,
            animations: view.layoutIfNeeded
        )
    }
    
    private func reloadViews(chain: Web3Chain) {
        networkNameLabel.text = chain.name
        selectNetworkButton.menu = UIMenu(children: Web3Chain.all.map { chain in
            UIAction(
                title: chain.name,
                state: chain == selectedChain ? .on : .off,
                handler: { [weak self] _ in self?.selectedChain = chain }
            )
        })
    }
    
}

extension AddWalletInputOnChainInfoViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension AddWalletInputOnChainInfoViewController: CameraViewControllerDelegate {
    
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool {
        inputTextView.text = string
        rearrangeInputButtons(controller)
        detectInput()
        return false
    }
    
}
