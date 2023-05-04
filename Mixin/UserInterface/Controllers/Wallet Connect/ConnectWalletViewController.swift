import UIKit
import WalletConnectSwift
import Web3Wallet
import MixinServices

final class ConnectWalletViewController: UIViewController {
    
    enum Info {
        case v1(WalletConnectSwift.Session.ClientMeta, WalletConnectService.Chain)
        case v2(WalletConnectSign.Session.Proposal)
        case bot(App)
        case page(String)
    }
    
    enum Error: Swift.Error {
        case invalidPIN
        case missingPINToken
    }
    
    @IBOutlet weak var tableView: AuthorizationScopesTableView!
    @IBOutlet weak var chainStackView: UIStackView!
    @IBOutlet weak var chainNameLabel: UILabel!
    
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var showChainConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideChainConstraint: NSLayoutConstraint!
    
    @MainActor var onApprove: ((Data) -> Void)?
    @MainActor var onReject: (() -> Void)?
    
    private let info: Info
    
    init(info: Info) {
        self.info = info
        super.init(nibName: R.nib.connectWalletView.name, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.reloadData()
        switch info {
        case let .v1(_, chain):
            setChainName(chain.name)
        case .v2, .bot, .page:
            setChainName(nil)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableViewHeightConstraint.constant = tableView.contentSize.height
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.isScrollEnabled = tableView.frame.height < tableView.contentSize.height
    }
    
    private func setChainName(_ name: String?) {
        if let name {
            chainStackView.isHidden = false
            showChainConstraint.priority = .almostRequired
            hideChainConstraint.priority = .almostInexist
            chainNameLabel.text = name
        } else {
            chainStackView.isHidden = true
            showChainConstraint.priority = .almostInexist
            hideChainConstraint.priority = .almostRequired
        }
    }
    
}

extension ConnectWalletViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        R.string.localizable.connect_wallet()
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        switch info {
        case let .v1(meta, _):
            if let url = meta.icons.first {
                return .url(url)
            } else {
                return nil
            }
        case let .v2(proposal):
            if let url = proposal.proposer.icons.lazy.compactMap(URL.init(string:)).first {
                return .url(url)
            } else {
                return nil
            }
        case let .bot(app):
            return .app(app)
        case .page:
            return nil
        }
    }
    
    var intentSubtitle: String {
        switch info {
        case let .v1(meta, _):
            return meta.name
        case let .v2(proposal):
            return proposal.proposer.name
        case let .bot(app):
            return app.name + " (" + app.appNumber + ")"
        case let .page(host):
            return host
        }
    }
    
    var isBiometryAuthAllowed: Bool {
        true
    }
    
    var inputPINOnAppear: Bool {
        true
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (Swift.Error?) -> Void
    ) {
        Task {
            do {
                let priv = try await TIP.ethereumPrivateKey(pin: pin)
                await MainActor.run {
                    self.onApprove?(priv)
                    completion(nil)
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    completion(error)
                }
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        onReject?()
    }
    
}

extension ConnectWalletViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.authorization_scope_list, for: indexPath)!
        if indexPath.row == 0 {
            cell.titleLabel.text = R.string.localizable.read_your_public_address()
            cell.descriptionLabel.text = R.string.localizable.allow_dapp_access_public_address()
        } else {
            cell.titleLabel.text = R.string.localizable.request_approval()
            cell.descriptionLabel.text = R.string.localizable.allow_dapp_request_approval()
        }
        cell.checkmarkView.status = .nonSelectable
        return cell
    }
    
}
