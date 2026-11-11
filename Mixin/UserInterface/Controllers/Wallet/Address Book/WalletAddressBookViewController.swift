import UIKit
import MixinServices

final class WalletAddressBookViewController: UIViewController {
    
    typealias ValuableOnChainToken = any ValuableToken & OnChainToken
    
    enum Intent {
        // Browse addresses of all networks, view details or add new ones
        case manage
        // Select an address for sending the token, adding with the token's network only
        case select(token: ValuableOnChainToken, onSelect: (Address) -> Void)
    }
    
    private let intent: Intent
    private let searchBoxView = SearchBoxView()
    private let networkFilterView = AddressBookNetworkFilterView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    private var networks: [AddressBookNetwork] = []
    private var selectedChainIDs: [String]
    private var addresses: [AddressItem] = []
    private var filteredAddresses: [AddressItem] = []
    
    private var selectedNetworks: [AddressBookNetwork] {
        selectedChainIDs.compactMap { chainID in
            networks.first { $0.chainID == chainID }
        }
    }
    
    init(intent: Intent) {
        self.intent = intent
        switch intent {
        case .manage:
            self.selectedChainIDs = []
        case let .select(token, _):
            self.selectedChainIDs = [token.chainID]
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background_secondary()
        
        let searchWrapperView = UIView()
        view.addSubview(searchWrapperView)
        searchWrapperView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(70)
        }
        searchBoxView.contentView.backgroundColor = R.color.background()
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_address()
        searchBoxView.textField.addTarget(self, action: #selector(reloadFilteredAddresses), for: .editingChanged)
        searchWrapperView.addSubview(searchBoxView)
        searchBoxView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }
        var cancelConfiguration: UIButton.Configuration = .plain()
        cancelConfiguration.baseForegroundColor = R.color.theme()
        cancelConfiguration.attributedTitle = AttributedString(
            R.string.localizable.cancel(),
            attributes: AttributeContainer([.font: UIFont.preferredFont(forTextStyle: .callout)])
        )
        cancelConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        let cancelButton = UIButton(configuration: cancelConfiguration)
        cancelButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        searchWrapperView.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.leading.equalTo(searchBoxView.snp.trailing)
            make.trailing.centerY.equalToSuperview()
            make.height.greaterThanOrEqualTo(44)
        }
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        cancelButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        view.addSubview(networkFilterView)
        networkFilterView.snp.makeConstraints { make in
            make.top.equalTo(searchWrapperView.snp.bottom)
            make.leading.equalToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
        }
        networkFilterView.button.showsMenuAsPrimaryAction = false
        switch intent {
        case .manage:
            networkFilterView.button.addTarget(self, action: #selector(pickNetworks(_:)), for: .touchUpInside)
        case .select:
            // Only addresses on the network of the sending token are selectable
            networkFilterView.button.isEnabled = false
            networkFilterView.contentStackView.arrangedSubviews.last?.isHidden = true
        }
        
        let addButton = StyledButton(type: .system)
        addButton.style = .filled
        addButton.setTitle(R.string.localizable.add_address(), for: .normal)
        addButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16), adjustForContentSize: true)
        addButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        addButton.addTarget(self, action: #selector(addAddress(_:)), for: .touchUpInside)
        view.addSubview(addButton)
        addButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
        }
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 116
        tableView.contentInset = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        tableView.tableFooterView = UIView()
        tableView.register(AddressBookCell.self, forCellReuseIdentifier: AddressBookCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(networkFilterView.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(addButton.snp.top).offset(-16)
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadLocalAddresses),
            name: AddressDAO.addressDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadLocalAddresses),
            name: ChainDAO.chainsDidChangeNotification,
            object: nil
        )
        reloadLocalAddresses()
        let tokenChainID: String? = switch intent {
        case .manage:
            nil
        case let .select(token, _):
            token.chainID
        }
        DispatchQueue.global().async {
            let syncingChainIDs: [String] = if let tokenChainID {
                [tokenChainID]
            } else {
                AddressBookNetwork.all(
                    chains: ChainDAO.shared.allChains(),
                    supportedChainIDs: AddressBookNetwork.currentWalletChainIDs(),
                    usesDatabaseChainsOnly: false,
                ).map(\.chainID)
            }
            for chainID in syncingChainIDs {
                AddressAPI.addresses(chainID: chainID) { result in
                    guard case let .success(addresses) = result else {
                        return
                    }
                    DispatchQueue.global().async {
                        AddressDAO.shared.insertOrUpdateAddress(addresses: addresses)
                    }
                }
            }
        }
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func pickNetworks(_ sender: Any) {
        searchBoxView.textField.resignFirstResponder()
        let picker = AddressBookNetworkFilterPickerViewController(
            networks: networks,
            selectedNetworks: selectedNetworks
        )
        picker.onApply = { [weak self] networks in
            guard let self else {
                return
            }
            self.selectedChainIDs = networks.map(\.chainID)
            self.networkFilterView.reloadData(networks: networks)
            self.reloadFilteredAddresses()
        }
        present(picker, animated: true)
    }
    
    @objc private func addAddress(_ sender: Any) {
        searchBoxView.textField.resignFirstResponder()
        switch intent {
        case .manage:
            let networks = self.networks
            guard let network = AddressBookNetwork.defaultNetwork(
                selectedChainIDs: Set(selectedChainIDs),
                networks: networks
            ) else {
                return
            }
            presentingViewController?.dismiss(animated: true) {
                // The native asset of a chain shares the chain's ID
                AddressBookTokenLoader.load(assetID: network.chainID, chain: network.chain) { token in
                    let input: AddressInfoInputViewController = .newAddress(token: token, switchableNetworks: networks)
                    UIApplication.shared.homeNavigationController?.pushViewController(input, animated: true)
                }
            }
        case let .select(token, _):
            presentingViewController?.dismiss(animated: true) {
                let input: AddressInfoInputViewController = .newAddress(token: token, switchableNetworks: nil)
                UIApplication.shared.homeNavigationController?.pushViewController(input, animated: true)
            }
        }
    }
    
    @objc private func reloadLocalAddresses() {
        // Sending tokens limits the network already, others follow the current wallet
        let usesCurrentWalletChains = switch intent {
        case .manage:
            true
        case .select:
            false
        }
        let usesDatabaseChainsOnly = switch (intent, AppGroupUserDefaults.Wallet.lastSelectedWallet) {
        case (.manage, .privacy):
            true
        default:
            false
        }
        DispatchQueue.global().async { [weak self] in
            let supportedChainIDs = usesCurrentWalletChains ? AddressBookNetwork.currentWalletChainIDs() : nil
            let addresses = AddressDAO.shared.addressItems().filter { address in
                (supportedChainIDs?.contains(address.chainId) ?? true)
            }
            let networks = AddressBookNetwork.all(
                chains: ChainDAO.shared.allChains(),
                supportedChainIDs: supportedChainIDs,
                usesDatabaseChainsOnly: usesDatabaseChainsOnly,
            )
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.addresses = addresses
                self.networks = networks
                self.networkFilterView.reloadData(networks: self.selectedNetworks)
                self.reloadFilteredAddresses()
            }
        }
    }
    
    @objc private func reloadFilteredAddresses() {
        let chainIDs = Set(selectedChainIDs)
        let keyword = searchBoxView.trimmedLowercaseText
        filteredAddresses = addresses.filter { address in
            (chainIDs.isEmpty || chainIDs.contains(address.chainId))
            && (keyword.isEmpty || address.matches(lowercasedKeyword: keyword))
        }
        tableView.reloadData()
        tableView.checkEmpty(
            dataCount: filteredAddresses.count,
            text: keyword.isEmpty ? R.string.localizable.no_records() : R.string.localizable.no_records_found(),
            photo: R.image.emptyIndicator.ic_data()!
        )
    }
    
}

extension WalletAddressBookViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredAddresses.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AddressBookCell.reuseIdentifier, for: indexPath) as! AddressBookCell
        let address = filteredAddresses[indexPath.row]
        cell.load(address: address, network: networks.first { $0.chainID == address.chainId })
        return cell
    }
    
}

extension WalletAddressBookViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let address = filteredAddresses[indexPath.row]
        switch intent {
        case .manage:
            let network = networks.first { $0.chainID == address.chainId }
            presentingViewController?.dismiss(animated: true) {
                let detail = AddressBookAddressViewController(address: address, network: network)
                UIApplication.shared.homeNavigationController?.pushViewController(detail, animated: true)
            }
        case let .select(_, onSelect):
            onSelect(address)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let address = filteredAddresses[indexPath.row]
        let delete = UIContextualAction(
            style: .destructive,
            title: R.string.localizable.delete()
        ) { [weak self] (_, _, completionHandler) in
            guard let self else {
                completionHandler(false)
                return
            }
            self.searchBoxView.textField.resignFirstResponder()
            let presentPreview = { [weak self] (token: any OnChainToken) in
                let preview = EditAddressPreviewViewController(
                    token: token,
                    label: address.label,
                    destination: address.destination,
                    tag: address.tag,
                    action: .delete(id: address.addressId),
                )
                self?.present(preview, animated: true)
            }
            switch self.intent {
            case .manage:
                let network = self.networks.first { $0.chainID == address.chainId }
                AddressBookTokenLoader.load(
                    assetID: address.assetId,
                    chain: network?.chain,
                    completion: presentPreview
                )
            case let .select(token, _):
                presentPreview(token)
            }
            completionHandler(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
    
}
