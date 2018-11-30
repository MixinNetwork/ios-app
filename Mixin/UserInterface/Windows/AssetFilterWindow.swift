import UIKit

protocol AssetFilterWindowDelegate: class {
    func assetFilterWindow(_ window: AssetFilterWindow, didApplySort sort: Snapshot.Sort, filter: Snapshot.Filter)
}

class AssetFilterWindow: BottomSheetView {
    
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    
    weak var delegate: AssetFilterWindowDelegate?

    private(set) var sort = Snapshot.Sort.createdAt
    private(set) var filter = Snapshot.Filter.all
    
    private lazy var sortDraft = sort
    private lazy var filterDraft = filter
    
    private let cellReuseId = "cell"
    private let headers = [
        Localized.TRANSACTIONS_FILTER_SORT_BY,
        Localized.TRANSACTIONS_FILTER_FILTER_BY
    ]
    private let titles = [
        [Localized.TRANSACTIONS_FILTER_SORT_BY_TIME,
         Localized.TRANSACTIONS_FILTER_SORT_BY_AMOUNT],
        [Localized.TRANSACTIONS_FILTER_FILTER_BY_ALL,
         Localized.TRANSACTION_TYPE_TRANSFER,
         Localized.TRANSACTION_TYPE_DEPOSIT,
         Localized.TRANSACTION_TYPE_WITHDRAWAL,
         Localized.TRANSACTION_TYPE_FEE,
         Localized.TRANSACTION_TYPE_REBATE]
    ]
    
    class func instance() -> AssetFilterWindow {
        let window = Bundle.main.loadNibNamed("AssetFilterWindow", owner: nil, options: nil)?.first as! AssetFilterWindow
        if let windowFrame = UIApplication.shared.keyWindow?.bounds {
            window.frame = windowFrame
        }
        return window
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        dismissButton.addTarget(self, action: #selector(dismissPopupControllerAnimated), for: .touchUpInside)
        tableView.register(UINib(nibName: "TransactionsFilterConditionCell", bundle: .main), forCellReuseIdentifier: cellReuseId)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        reloadSelection()
        updateTableViewHeightAndScrollingEnabledIfNeeded()
    }
    
    @available(iOS 11.0, *)
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateTableViewHeightAndScrollingEnabledIfNeeded()
    }
    
    override func presentPopupControllerAnimated() {
        sortDraft = sort
        filterDraft = filter
        reloadSelection()
        super.presentPopupControllerAnimated()
    }
    
    @IBAction func applyAction(_ sender: Any) {
        sort = sortDraft
        filter = filterDraft
        delegate?.assetFilterWindow(self, didApplySort: sort, filter: filter)
        dismissPopupControllerAnimated()
    }
    
}

extension AssetFilterWindow: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId, for: indexPath) as! TransactionsFilterConditionCell
        cell.titleLabel.text = titles[indexPath.section][indexPath.row]
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return headers.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return headers[section]
    }

}

extension AssetFilterWindow: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let indexPathToDeselect = IndexPath(row: 1 - indexPath.row, section: indexPath.section)
            tableView.deselectRow(at: indexPathToDeselect, animated: true)
            sortDraft = indexPath.row == 0 ? .createdAt : .amount
        } else {
            for indexPathToDeselect in tableView.indexPathsForSelectedRows ?? [] {
                guard indexPathToDeselect.section == 1 && indexPathToDeselect != indexPath else {
                    continue
                }
                tableView.deselectRow(at: indexPathToDeselect, animated: true)
            }
            filterDraft = filter(for: indexPath.row)
        }
    }
    
    func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
}

extension AssetFilterWindow {
    
    private func reloadSelection() {
        for indexPath in tableView.indexPathsForSelectedRows ?? [] {
            tableView.deselectRow(at: indexPath, animated: false)
        }
        switch sort {
        case .createdAt:
            tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
        case .amount:
            tableView.selectRow(at: IndexPath(row: 1, section: 0), animated: false, scrollPosition: .none)
        }
        switch filter {
        case .all:
            tableView.selectRow(at: IndexPath(row: 0, section: 1), animated: false, scrollPosition: .none)
        case .transfer:
            tableView.selectRow(at: IndexPath(row: 1, section: 1), animated: false, scrollPosition: .none)
        case .deposit:
            tableView.selectRow(at: IndexPath(row: 2, section: 1), animated: false, scrollPosition: .none)
        case .withdrawal:
            tableView.selectRow(at: IndexPath(row: 3, section: 1), animated: false, scrollPosition: .none)
        case .fee:
            tableView.selectRow(at: IndexPath(row: 4, section: 1), animated: false, scrollPosition: .none)
        case .rebate:
            tableView.selectRow(at: IndexPath(row: 5, section: 1), animated: false, scrollPosition: .none)
        }
    }
    
    private func updateTableViewHeightAndScrollingEnabledIfNeeded() {
        tableViewHeightConstraint.constant = ceil(tableView.contentSize.height) + 8
        tableView.isScrollEnabled = tableView.contentSize.height >= tableView.frame.height
    }
    
    private func filter(for row: Int) -> Snapshot.Filter {
        switch row {
        case 0:
            return .all
        case 1:
            return .transfer
        case 2:
            return .deposit
        case 3:
            return .withdrawal
        case 4:
            return .fee
        default:
            return .rebate
        }
    }
    
}
