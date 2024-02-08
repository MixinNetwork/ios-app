import UIKit
import web3
import MixinServices

class WalletConnectRequestViewController: UIViewController {
    
    enum Requester {
        case walletConnect(WalletConnectSession)
        case app(App)
        case page(String)
    }
    
    @IBOutlet weak var messageWrapperView: UIView!
    @IBOutlet weak var networkStackView: UIStackView!
    @IBOutlet weak var chainNameLabel: UILabel!
    @IBOutlet weak var feeLabel: UILabel!
    @IBOutlet weak var feeSelectorImageView: UIImageView!
    @IBOutlet weak var feeButton: UIButton!
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
    
    private let requester: Requester
    
    private(set) var isApproved = false
    
    var signingCompletionView: UIView {
        UIView()
    }
    
    init(requester: Requester) {
        self.requester = requester
        super.init(nibName: R.nib.walletConnectRequestView.name, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        signButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 28, bottom: 12, right: 28)
    }
    
    @IBAction func changeFee(_ sender: Any) {
        
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

extension WalletConnectRequestViewController: AuthenticationIntent {
    
    @objc var intentTitle: String {
        "WalletConnect Request"
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        switch requester {
        case let .walletConnect(session):
            if let url = session.iconURL {
                return .url(url)
            } else {
                return nil
            }
        case let .app(app):
            return .app(app)
        case .page:
            return nil
        }
    }
    
    var intentSubtitle: String {
        switch requester {
        case let .walletConnect(session):
            return session.name
        case let .app(app):
            return "\(app.name) (\(app.appNumber))"
        case let .page(host):
            return host
        }
    }
    
    var options: AuthenticationIntentOptions {
        []
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
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
                    completion(.success)
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error: error, retry: .inputPINAgain))
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
