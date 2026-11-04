import UIKit
import MixinServices

final class AddressBookAddressViewController: UIViewController {
    
    private enum Section: Int, CaseIterable {
        case info
        case transactions
    }
    
    private enum TransactionRow {
        case title
        case emptyIndicator
        case snapshot(SafeSnapshotItem)
        case web3Transaction(Web3Transaction)
        case viewAll
        case bottomSeparator
    }
    
    private enum Source {
        case privacy
        case common(Web3Wallet, Web3Wallet.Availability)
    }
    
    private let displayTransactionsCount = 10
    private let headerReuseIdentifier = "h"
    private let emptyCellReuseIdentifier = "e"
    
    private let address: AddressItem
    private let network: AddressBookNetwork?
    private let infoRows: [(title: String, value: String)]
    
    private weak var tableView: UITableView!
    
    private var source: Source?
    private var transactionRows: [TransactionRow] = [.title]
    private var hasMoreTransactions = false
    private var transactionTokenSymbols: [String: String] = [:]
    
    init(address: AddressItem, network: AddressBookNetwork?) {
        self.address = address
        self.network = network
        var infoRows: [(title: String, value: String)] = [
            (R.string.localizable.label(), address.label),
            (R.string.localizable.address(), address.destination),
            (R.string.localizable.network(), network?.name ?? ""),
        ]
        if !address.tag.isEmpty {
            infoRows.append((R.string.localizable.memo(), address.tag))
        }
        self.infoRows = infoRows
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
        title = R.string.localizable.address()
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_title_more(),
            target: self,
            action: #selector(showMoreActions(_:))
        )
        
        let tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.backgroundColor = R.color.background_secondary()
        tableView.alwaysBounceVertical = true
        tableView.estimatedRowHeight = 62
        tableView.separatorStyle = .none
        tableView.register(R.nib.snapshotColumnCell)
        tableView.register(R.nib.insetGroupedTitleCell)
        tableView.register(R.nib.noTransactionIndicatorCell)
        tableView.register(R.nib.snapshotCell)
        tableView.register(R.nib.web3TransactionCell)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: emptyCellReuseIdentifier)
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: headerReuseIdentifier)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView = tableView
        
        let center: NotificationCenter = .default
        center.addObserver(self, selector: #selector(addressDidChange(_:)), name: AddressDAO.addressDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(reloadTransactions), name: SafeSnapshotDAO.snapshotDidSaveNotification, object: nil)
        center.addObserver(self, selector: #selector(reloadTransactions), name: Web3TransactionDAO.transactionDidUpdateNotification, object: nil)
        reloadTransactions()
    }
    
    @objc private func showMoreActions(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.delete_address(), style: .destructive, handler: { [address, network] _ in
            AddressBookTokenLoader.load(assetID: address.assetId, chain: network?.chain) { [weak self] token in
                let preview = EditAddressPreviewViewController(
                    token: token,
                    label: address.label,
                    destination: address.destination,
                    tag: address.tag,
                    action: .delete(id: address.addressId),
                )
                self?.navigationController?.present(preview, animated: true)
            }
        }))
        if #available(iOS 26.0, *), let source = sender as? UIBarButtonItem {
            sheet.popoverPresentationController?.sourceItem = source
        } else {
            sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        }
        present(sheet, animated: true, completion: nil)
    }
    
    @objc private func addressDidChange(_ notification: Notification) {
        let addressID = address.addressId
        DispatchQueue.global().async {
            guard AddressDAO.shared.getAddress(addressId: addressID) == nil else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, let navigationController = self.navigationController else {
                    return
                }
                if navigationController.topViewController == self {
                    navigationController.popViewController(animated: true)
                } else {
                    navigationController.viewControllers.removeAll { $0 == self }
                }
            }
        }
    }
    
    @objc private func reloadTransactions() {
        let address = self.address
        let limit = displayTransactionsCount
        DispatchQueue.global().async { [weak self] in
            let source: Source
            let transactions: [TransactionRow]
            let hasMore: Bool
            var tokenSymbols: [String: String] = [:]
            if case let .common(walletID) = AppGroupUserDefaults.Wallet.lastSelectedWallet,
               let wallet = Web3WalletDAO.shared.wallet(id: walletID)
            {
                let availability: Web3Wallet.Availability = if wallet.hasSecret() {
                    .always
                } else {
                    Web3Wallet.Availability(
                        wallet: wallet,
                        importedSecret: nil,
                        supportedChainIDs: Web3AddressDAO.shared.chainIDs(walletID: wallet.walletID)
                    )
                }
                source = .common(wallet, availability)
                let items = Web3TransactionDAO.shared.transactions(
                    walletID: wallet.walletID,
                    filter: .init(addresses: [address]),
                    order: .newest,
                    limit: limit + 1
                )
                hasMore = items.count > limit
                let displayItems = items.prefix(limit)
                var assetIDs: Set<String> = []
                for item in displayItems {
                    assetIDs.formUnion(item.allAssetIDs)
                }
                tokenSymbols = Web3TokenDAO.shared.tokenSymbols(ids: assetIDs)
                    .mapValues { symbol in
                        TextTruncation.truncateTail(string: symbol, prefixCount: 8)
                    }
                transactions = displayItems.map { .web3Transaction($0) }
            } else {
                source = .privacy
                let items = SafeSnapshotDAO.shared.snapshots(
                    filter: .init(addresses: [address]),
                    order: .newest,
                    limit: limit + 1
                )
                hasMore = items.count > limit
                transactions = items.prefix(limit).map { .snapshot($0) }
            }
            let rows: [TransactionRow] = if transactions.isEmpty {
                [.title, .emptyIndicator]
            } else if hasMore {
                [.title] + transactions + [.viewAll, .bottomSeparator]
            } else {
                [.title] + transactions + [.bottomSeparator]
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.source = source
                self.transactionTokenSymbols = tokenSymbols
                self.transactionRows = rows
                self.hasMoreTransactions = hasMore
                UIView.performWithoutAnimation {
                    self.tableView.reloadSections(IndexSet(integer: Section.transactions.rawValue), with: .none)
                }
            }
        }
    }
    

}

extension AddressBookAddressViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .info:
            infoRows.count
        case .transactions:
            transactionRows.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .info:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot_column, for: indexPath)!
            let row = infoRows[indexPath.row]
            cell.titleLabel.text = row.title.localizedUppercase
            cell.subtitleLabel.text = row.value
            cell.subtitleLabel.textColor = R.color.text()
            cell.disclosureIndicatorImageView.isHidden = true
            return cell
        case .transactions:
            switch transactionRows[indexPath.row] {
            case .title:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inset_grouped_title, for: indexPath)!
                cell.label.text = R.string.localizable.transactions()
                cell.disclosureIndicatorView.isHidden = !hasMoreTransactions
                return cell
            case .emptyIndicator:
                return tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.no_transaction_indicator, for: indexPath)!
            case let .snapshot(snapshot):
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot, for: indexPath)!
                cell.render(snapshot: snapshot)
                return cell
            case let .web3Transaction(transaction):
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_transaction, for: indexPath)!
                cell.load(transaction: transaction, symbols: transactionTokenSymbols)
                return cell
            case .bottomSeparator:
                let cell = tableView.dequeueReusableCell(withIdentifier: emptyCellReuseIdentifier, for: indexPath)
                cell.backgroundConfiguration = .groupedCell
                cell.contentConfiguration = nil
                return cell
            case .viewAll:
                let cell = tableView.dequeueReusableCell(withIdentifier: emptyCellReuseIdentifier, for: indexPath)
                cell.backgroundConfiguration = .groupedCell
                cell.contentConfiguration = {
                    var content = cell.defaultContentConfiguration()
                    content.text = R.string.localizable.view_all()
                    content.textProperties.alignment = .center
                    content.textProperties.font = .scaledFont(ofSize: 14, weight: .regular)
                    content.textProperties.color = R.color.theme()!
                    return content
                }()
                return cell
            }
        }
    }
    
}

extension AddressBookAddressViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .info:
            UITableView.automaticDimension
        case .transactions:
            switch transactionRows[indexPath.row] {
            case .title, .emptyIndicator, .viewAll:
                UITableView.automaticDimension
            case .snapshot, .web3Transaction:
                62
            case .bottomSeparator:
                10
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Round both cards with the wallet card radius instead of the system one
        let cornerRadius: CGFloat = 8
        let isFirstRow = indexPath.row == 0
        let isLastRow = indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1
        if #available(iOS 26.0, *) {
            let topRadius: UICornerRadius? = isFirstRow ? .fixed(cornerRadius) : nil
            let bottomRadius: UICornerRadius? = isLastRow ? .fixed(cornerRadius) : nil
            cell.cornerConfiguration = .corners(
                topLeftRadius: topRadius,
                topRightRadius: topRadius,
                bottomLeftRadius: bottomRadius,
                bottomRightRadius: bottomRadius,
            )
        } else if isFirstRow || isLastRow {
            cell.layer.cornerRadius = cornerRadius
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        10
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch Section(rawValue: section)! {
        case .info:
            8
        case .transactions:
            .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseIdentifier)!
        view.contentView.backgroundColor = R.color.background_secondary()
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .transactions else {
            return
        }
        switch transactionRows[indexPath.row] {
        case .title, .viewAll:
            guard hasMoreTransactions else {
                return
            }
            switch source {
            case .privacy:
                let history = MixinTransactionHistoryViewController(address: address)
                navigationController?.pushViewController(history, animated: true)
            case let .common(wallet, availability):
                let history = Web3TransactionHistoryViewController(
                    wallet: wallet,
                    address: address,
                    availability: availability,
                )
                navigationController?.pushViewController(history, animated: true)
            case .none:
                break
            }
        case let .snapshot(snapshot):
            if let viewController = SafeSnapshotViewController(snapshot: snapshot) {
                navigationController?.pushViewController(viewController, animated: true)
            }
        case let .web3Transaction(transaction):
            guard case let .common(wallet, availability) = source else {
                return
            }
            let viewController = Web3TransactionViewController(
                wallet: wallet,
                transaction: transaction,
                availability: availability
            )
            navigationController?.pushViewController(viewController, animated: true)
        case .emptyIndicator, .bottomSeparator:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        Section(rawValue: indexPath.section) == .info
    }
    
    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        Section(rawValue: indexPath.section) == .info && action == #selector(copy(_:))
    }
    
    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        UIPasteboard.general.string = infoRows[indexPath.row].value
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}
