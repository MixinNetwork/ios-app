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
    
    private var savedAddress: Address?
    
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
        switch action {
        case .add:
            tableHeaderView.titleLabel.text = R.string.localizable.confirm_adding_address()
            tableHeaderView.subtitleLabel.text = R.string.localizable.review_address_hint()
        case .update:
            tableHeaderView.titleLabel.text = R.string.localizable.confirm_editing_address()
            tableHeaderView.subtitleLabel.text = R.string.localizable.review_address_hint()
        case .delete:
            tableHeaderView.titleLabel.text = R.string.localizable.confirm_deleting_address()
            tableHeaderView.subtitleLabel.text = R.string.localizable.delete_address_description()
        }
        
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
        switch action {
        case .add:
            layoutTableHeaderView(title: R.string.localizable.adding_address(),
                                  subtitle: R.string.localizable.address_adding_description())
        case .update:
            layoutTableHeaderView(title: R.string.localizable.editing_address(),
                                  subtitle: R.string.localizable.address_editing_description())
        case .delete:
            layoutTableHeaderView(title: R.string.localizable.deleting_address(),
                                  subtitle: nil)
        }
        replaceTrayView(with: nil, animation: .vertical)
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
                    self.savedAddress = address
                    self.loadSuccessViews()
                    self.onSavingSuccess?()
                    DispatchQueue.global().async {
                        AddressDAO.shared.insertOrUpdateAddress(addresses: [address])
                    }
                case let .failure(error):
                    self.savedAddress = nil
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
                self.savedAddress = nil
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
    
    @objc private func withdraw(_ sender: Any) {
        guard let address = savedAddress else {
            return
        }
        presentingViewController?.dismiss(animated: true) { [token] in
            guard let navigationController = UIApplication.homeNavigationController else {
                return
            }
            let transfer = TransferOutViewController.instance(token: token, to: .address(address))
            navigationController.pushViewController(transfer, animated: true)
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
        tableView.setContentOffset(.zero, animated: true)
        switch action {
        case .add, .update:
            loadDoubleButtonTrayView(leftTitle: R.string.localizable.close(),
                                     leftAction: #selector(close(_:)),
                                     rightTitle: R.string.localizable.withdrawal(),
                                     rightAction: #selector(withdraw(_:)),
                                     animation: .vertical)
        case .delete:
            loadSingleButtonTrayView(title: R.string.localizable.done(),
                                     action:  #selector(close(_:)))
        }
    }
    
    private func loadFailureViews(errorDescription: String) {
        tableHeaderView.setIcon(progress: .failure)
        let title = switch action {
        case .add:
            R.string.localizable.adding_address_failed()
        case .update:
            R.string.localizable.editing_address_failed()
        case .delete:
            R.string.localizable.deleting_address_failed()
        }
        layoutTableHeaderView(title: title, subtitle: errorDescription, style: .destructive)
        tableView.setContentOffset(.zero, animated: true)
        loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                 leftAction: #selector(self.close(_:)),
                                 rightTitle: R.string.localizable.retry(),
                                 rightAction: #selector(self.confirm(_:)),
                                 animation: .vertical)
    }
    
}
