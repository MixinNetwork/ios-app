import UIKit
import web3
import MixinServices

class WalletConnectRequestViewController: UIViewController {
    
    @IBOutlet weak var messageWrapperView: UIView!
    @IBOutlet weak var networkStackView: UIStackView!
    @IBOutlet weak var chainNameLabel: UILabel!
    @IBOutlet weak var feeLabel: UILabel!
    @IBOutlet weak var warningWrapperView: UIView!
    @IBOutlet weak var warningIconView: UIImageView!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var signActionsStackView: UIStackView!
    @IBOutlet weak var signButton: RoundedButton!
    
    @IBOutlet weak var networkStackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var warningWrapperViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var signActionsStackViewTopConstraint: NSLayoutConstraint!
    
    @MainActor var onReject: (() -> Void)?
    @MainActor var onApprove: ((Data) async throws -> Void)?
    
    private let session: WalletConnectSession
    
    private(set) var isApproved = false
    
    var signingCompletionView: UIView {
        UIView()
    }
    
    init(session: WalletConnectSession) {
        self.session = session
        super.init(nibName: R.nib.walletConnectRequestView.name, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 15.0, *) {
            signButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 28, bottom: 12, trailing: 28)
        } else {
            signButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 28, bottom: 12, right: 28)
        }
    }
    
    @IBAction func signByPIN(_ sender: Any) {
        updateConstraints(state: .signing)
        UIView.animate(withDuration: 0.3) {
            self.signActionsStackView.alpha = 0
            self.view.layoutIfNeeded()
        }
        authenticationViewController?.beginPINInputting()
    }
    
    @IBAction func cancelSigning(_ sender: Any) {
        onReject?()
        authenticationViewController?.presentingViewController?.dismiss(animated: true)
    }
    
}

extension WalletConnectRequestViewController: AuthenticationIntentViewController {
    
    @objc var intentTitle: String {
        "WalletConnect Request"
    }
    
    var intentSubtitleIconURL: URL? {
        session.iconURL
    }
    
    var intentSubtitle: String {
        session.name
    }
    
    var isBiometryAuthAllowed: Bool {
        false
    }
    
    var inputPINOnAppear: Bool {
        false
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (Swift.Error?) -> Void
    ) {
        Task {
            do {
                let priv = try await TIP.ethereumPrivateKey(pin: pin)
                try await onApprove?(priv)
                await MainActor.run {
                    self.isApproved = true
                    self.loadSigningCompletionView()
                    self.authenticationViewController?.endPINInputting {
                        self.signingCompletionView.alpha = 1
                        self.updateConstraints(state: .sending)
                    }
                    completion(nil)
                }
            } catch {
                await MainActor.run {
                    completion(error)
                }
            }
        }
    }
    
    @objc func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}

extension WalletConnectRequestViewController {
    
    private enum State {
        case confirmation
        case signing
        case sending
    }
    
    private func updateConstraints(state: State) {
        switch state {
        case .confirmation:
            networkStackViewBottomConstraint.constant = warningWrapperViewTopConstraint.constant
            + warningWrapperView.frame.height
            + signActionsStackViewTopConstraint.constant
            + signActionsStackView.frame.height
            + 18
        case .signing:
            networkStackViewBottomConstraint.constant = warningWrapperViewTopConstraint.constant
            + warningWrapperView.frame.height
            + 10
        case .sending:
            networkStackViewBottomConstraint.constant = 40
            + signingCompletionView.frame.height
            + 25
        }
    }
    
    private func loadSigningCompletionView() {
        warningWrapperView.alpha = 0
        signActionsStackView.alpha = 0
        
        let signingCompletionView = self.signingCompletionView
        if signingCompletionView.superview == nil {
            view.addSubview(signingCompletionView)
            signingCompletionView.snp.makeConstraints { make in
                make.top.equalTo(networkStackView.snp.bottom).offset(40)
                make.leading.equalToSuperview().offset(28)
                make.trailing.equalToSuperview().offset(-28)
            }
        }
        signingCompletionView.alpha = 0
        
        view.layoutIfNeeded()
    }
    
}
