import UIKit
import MixinServices

final class EditAddressPreviewViewController: AuthenticationPreviewViewController {
    
    enum Action {
        case add
        case update
        case delete(id: String)
    }
    
    var onSavingSuccess: (() -> Void)?
    
    private let token: any OnChainToken
    private let label: String
    private let destination: String
    private let tag: String
    private let action: Action
    
    private var savedAddress: Address?
    
    init(token: any OnChainToken, label: String, destination: String, tag: String, action: Action) {
        self.token = token
        self.label = label
        self.destination = destination
        self.tag = tag
        self.action = action
        super.init(warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let chain = token.chain {
            tableHeaderView.setIcon(chain: chain)
        }
        switch action {
        case .add:
            reporter.report(event: .addAddressPreview)
            tableHeaderView.titleLabel.text = R.string.localizable.confirm_adding_address()
            tableHeaderView.subtitleTextView.text = R.string.localizable.review_address_hint()
        case .update:
            tableHeaderView.titleLabel.text = R.string.localizable.confirm_editing_address()
            tableHeaderView.subtitleTextView.text = R.string.localizable.review_address_hint()
        case .delete:
            tableHeaderView.titleLabel.text = R.string.localizable.confirm_deleting_address()
            tableHeaderView.subtitleTextView.text = R.string.localizable.delete_address_description()
        }
        
        var rows: [Row] = [
            .info(caption: .label, content: label),
            .info(caption: .address, content: destination),
        ]
        if !tag.isEmpty {
            let caption: Caption = token.usesTag ? .tag : .memo
            rows.append(.info(caption: caption, content: tag))
        }
        rows.append(.info(caption: .network, content: token.depositNetworkName ?? ""))
        reloadData(with: rows)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
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
        switch action {
        case .add, .update:
            let request = AddressRequest(chainID: token.chainID,
                                         assetID: token.assetID,
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
                    let errorDescription = if case MixinAPIResponseError.malformedAddress = error {
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
            AddressAPI.delete(addressID: id, pin: pin) { result in
                self.canDismissInteractively = true
                self.savedAddress = nil
                switch result {
                case .success:
                    self.loadSuccessViews()
                    DispatchQueue.global().async {
                        AddressDAO.shared.deleteAddress(addressId: id)
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
        tableView.setContentOffset(.zero, animated: true)
        loadSingleButtonTrayView(title: R.string.localizable.done(), action:  #selector(close(_:)))
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
