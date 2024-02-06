import UIKit
import MixinServices

final class EditAddressPreviewViewController: PaymentPreviewViewController {
    
    enum Action {
        case add
        case update
        case delete(id: String)
    }
    
    var onSavingSuccess: (() -> Void)?
    
    override var authenticationTitle: String {
        switch action {
        case .add:
            R.string.localizable.add_by_pin()
        case .update:
            R.string.localizable.edit_by_pin()
        case .delete:
            R.string.localizable.delete_by_pin()
        }
    }
    
    private let token: TokenItem
    private let label: String
    private let destination: String
    private let tag: String
    private let action: Action
    
    init(token: TokenItem, label: String, destination: String, tag: String, action: Action) {
        self.token = token
        self.label = label
        self.destination = destination
        self.tag = tag
        self.action = action
        super.init(issues: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableHeaderView.setIcon(token: token)
        tableHeaderView.titleLabel.text = switch action {
        case .add:
            R.string.localizable.confirm_adding_address()
        case .update:
            R.string.localizable.confirm_editing_address()
        case .delete:
            R.string.localizable.confirm_deleteing_address()
        }
        tableHeaderView.subtitleLabel.text = R.string.localizable.review_address_hint()
        
        var rows: [Row] = [
            .info(caption: .label, content: label),
            .info(caption: .address, content: destination),
            .info(caption: .network, content: token.depositNetworkName ?? ""),
        ]
        if !tag.isEmpty {
            rows.append(.info(caption: .memo, content: tag))
        }
        reloadData(with: rows)
    }
    
    override func performAction(with pin: String) {
        tableHeaderView.setIcon(progress: .busy)
        layoutTableHeaderView(title: R.string.localizable.adding_address(),
                              subtitle: R.string.localizable.address_adding_description())
        replaceTrayView(with: nil, animated: true)
        canDismissInteractively = false
        switch action {
        case .add, .update:
            let request = AddressRequest(assetID: token.assetID,
                                         destination: destination,
                                         tag: tag,
                                         label: label,
                                         pin: pin)
            AddressAPI.save(request: request) { [token] result in
                self.canDismissInteractively = true
                switch result {
                case let .success(address):
                    self.loadSuccessViews()
                    self.onSavingSuccess?()
                    DispatchQueue.global().async {
                        AddressDAO.shared.insertOrUpdateAddress(addresses: [address])
                    }
                case let .failure(error):
                    let errorDescription = if case .malformedAddress = error {
                        if token.isEOSChain {
                            R.string.localizable.invalid_malformed_address_eos_hint()
                        } else if self.token.isERC20 {
                            R.string.localizable.invalid_malformed_address_hint("Ethereum(ERC20) \(token.symbol)")
                        } else {
                            R.string.localizable.invalid_malformed_address_hint(token.symbol)
                        }
                    } else {
                        error.localizedDescription
                    }
                    self.loadFailureViews(errorDescription: errorDescription)
                }
            }
        case .delete(let id):
            AddressAPI.delete(addressID: id, pin: pin) { [assetID=token.assetID] result in
                self.canDismissInteractively = true
                switch result {
                case .success:
                    self.loadSuccessViews()
                    DispatchQueue.global().async {
                        AddressDAO.shared.deleteAddress(assetId: assetID, addressId: id)
                    }
                case let .failure(error):
                    self.loadFailureViews(errorDescription: error.localizedDescription)
                }
            }
        }
    }
    
    private func loadSuccessViews() {
        tableHeaderView.setIcon(progress: .success)
        switch action {
        case .add:
            layoutTableHeaderView(title: R.string.localizable.address_added(),
                                  subtitle: R.string.localizable.address_added_description())
        case .update:
            layoutTableHeaderView(title: R.string.localizable.address_edited(),
                                  subtitle: R.string.localizable.address_edited_description())
        case .delete:
            layoutTableHeaderView(title: R.string.localizable.address_deleted(), subtitle: nil)
        }
        switch action {
        case .add, .update:
            loadDoubleButtonTrayView(leftTitle: R.string.localizable.close(),
                                     leftAction: #selector(close(_:)),
                                     rightTitle: R.string.localizable.withdrawal(),
                                     rightAction: #selector(close(_:)),
                                     animated: true)
        case .delete:
            loadSingleButtonTrayView(title: R.string.localizable.done(),
                                     action:  #selector(close(_:)))
        }
    }
    
    private func loadFailureViews(errorDescription: String) {
        tableHeaderView.setIcon(progress: .failure)
        switch action {
        case .add:
            layoutTableHeaderView(title: R.string.localizable.adding_address_failed(),
                                  subtitle: errorDescription)
        case .update:
            layoutTableHeaderView(title: R.string.localizable.editing_address_failed(),
                                  subtitle: errorDescription)
        case .delete:
            layoutTableHeaderView(title: R.string.localizable.address_deleted(),
                                  subtitle: errorDescription)
        }
        loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                 leftAction: #selector(self.close(_:)),
                                 rightTitle: R.string.localizable.retry(),
                                 rightAction: #selector(self.confirm(_:)),
                                 animated: true)
    }
    
}
