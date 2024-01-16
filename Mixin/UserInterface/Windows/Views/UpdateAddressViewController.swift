import UIKit
import Alamofire
import MixinServices

final class UpdateAddressViewController: UIViewController {
    
    enum Action {
        case add
        case update
        case delete(id: String)
    }
    
    private enum AddressMalformedError: Error, LocalizedError {
        
        case eos
        case erc20(symbol: String)
        case other(symbol: String)
        
        var errorDescription: String? {
            switch self {
            case .eos:
                return R.string.localizable.invalid_malformed_address_eos_hint()
            case .erc20(let symbol):
                return R.string.localizable.invalid_malformed_address_hint("Ethereum(ERC20) \(symbol)")
            case .other(let symbol):
                return R.string.localizable.invalid_malformed_address_hint(symbol)
            }
        }
        
    }
    
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    
    var onSuccess: (() -> Void)?
    
    private let token: TokenItem
    private let label: String
    private let destination: String
    private let tag: String
    private let action: Action
    
    init(token: TokenItem, delete address: Address) {
        self.token = token
        self.label = address.label
        self.destination = address.destination
        self.tag = address.tag
        self.action = .delete(id: address.addressId)
        let nib = R.nib.updateAddressView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    init(token: TokenItem, label: String, destination: String, tag: String, action: Action) {
        self.token = token
        self.label = label
        self.destination = destination
        self.tag = tag
        self.action = action
        let nib = R.nib.updateAddressView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        assetIconView.setIcon(token: token)
        nameLabel.text = label
        contentLabel.text = Address.fullRepresentation(destination: destination, tag: tag)
    }
    
}

extension UpdateAddressViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        switch action {
        case .add:
            return R.string.localizable.withdrawal_addr_new(token.symbol)
        case .update:
            return R.string.localizable.edit_address(token.symbol)
        case .delete:
            return R.string.localizable.delete_withdraw_address(token.symbol)
        }
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        token.depositNetworkName ?? ""
    }
    
    var options: AuthenticationIntentOptions {
        [.allowsBiometricAuthentication, .becomesFirstResponderOnAppear]
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        switch action {
        case .add, .update:
            let request = AddressRequest(assetID: token.assetID,
                                         destination: destination,
                                         tag: tag,
                                         label: label,
                                         pin: pin)
            AddressAPI.save(request: request) { [token] result in
                switch result {
                case let .success(address):
                    DispatchQueue.global().async {
                        AddressDAO.shared.insertOrUpdateAddress(addresses: [address])
                    }
                    completion(.success)
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.saved())
                    self.authenticationViewController?.presentingViewController?.dismiss(animated: true) {
                        self.onSuccess?()
                    }
                case .failure(.malformedAddress):
                    let error: AddressMalformedError
                    if self.token.isEOSChain {
                        error = .eos
                    } else if self.token.isERC20 {
                        error = .erc20(symbol: token.symbol)
                    } else {
                        error = .other(symbol: token.symbol)
                    }
                    completion(.failure(error: error, retry: .inputPINAgain))
                case let .failure(error):
                    completion(.failure(error: error, retry: .inputPINAgain))
                }
            }
        case let .delete(id):
            AddressAPI.delete(addressID: id, pin: pin) { [assetID=token.assetID] result in
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        AddressDAO.shared.deleteAddress(assetId: assetID, addressId: id)
                    }
                    completion(.success)
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.deleted())
                    self.authenticationViewController?.presentingViewController?.dismiss(animated: true) {
                        self.onSuccess?()
                    }
                case let .failure(error):
                    completion(.failure(error: error, retry: .inputPINAgain))
                }
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}
