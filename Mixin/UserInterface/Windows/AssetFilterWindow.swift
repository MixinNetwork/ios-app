import UIKit
import AlignedCollectionViewFlowLayout

protocol AssetFilterWindowDelegate: class {
    func assetFilterWindow(_ window: AssetFilterWindow, didApplySort sort: Snapshot.Sort, filter: Snapshot.Filter)
}

class AssetFilterWindow: BottomSheetView {
    
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    weak var delegate: AssetFilterWindowDelegate?
    
    private(set) var sort = Snapshot.Sort.createdAt
    private(set) var filter = Snapshot.Filter.all
    
    private lazy var sortDraft = sort
    private lazy var filterDraft = filter
    
    private let cellReuseId = "cell"
    private let headerReuseId = "header"
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
        collectionView.register(UINib(nibName: "TransactionsFilterConditionCell", bundle: .main),
                                forCellWithReuseIdentifier: cellReuseId)
        collectionView.register(AssetFilterHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: headerReuseId)
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        if let layout = collectionView.collectionViewLayout as? AlignedCollectionViewFlowLayout {
            layout.estimatedItemSize = CGSize(width: 96, height: 42)
            layout.horizontalAlignment = .left
        }
        collectionView.reloadData()
        reloadSelection()
        layoutIfNeeded()
        updatecollectionViewHeightAndScrollingEnabledIfNeeded()
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

extension AssetFilterWindow: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return titles[section].count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! TransactionsFilterConditionCell
        cell.titleLabel.text = titles[indexPath.section][indexPath.row]
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return headers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: headerReuseId, for: indexPath) as! AssetFilterHeaderView
        view.label.text = headers[indexPath.section]
        return view
    }
    
}

extension AssetFilterWindow: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let indexPathToDeselect = IndexPath(item: 1 - indexPath.row, section: indexPath.section)
            collectionView.deselectItem(at: indexPathToDeselect, animated: false)
            sortDraft = indexPath.row == 0 ? .createdAt : .amount
        } else {
            for indexPathToDeselect in collectionView.indexPathsForSelectedItems ?? [] {
                guard indexPathToDeselect.section == 1 && indexPathToDeselect != indexPath else {
                    continue
                }
                collectionView.deselectItem(at: indexPathToDeselect, animated: false)
            }
            filterDraft = filter(for: indexPath.row)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return false
    }
    
}

extension AssetFilterWindow: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if section == 0 {
            return UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        } else {
            return .zero
        }
    }
    
}

extension AssetFilterWindow {
    
    private func reloadSelection() {
        for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
            collectionView.deselectItem(at: indexPath, animated: false)
        }
        switch sort {
        case .createdAt:
            collectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .top)
        case .amount:
            collectionView.selectItem(at: IndexPath(item: 1, section: 0), animated: false, scrollPosition: .top)
        }
        switch filter {
        case .all:
            collectionView.selectItem(at: IndexPath(item: 0, section: 1), animated: false, scrollPosition: .top)
        case .transfer:
            collectionView.selectItem(at: IndexPath(item: 1, section: 1), animated: false, scrollPosition: .top)
        case .deposit:
            collectionView.selectItem(at: IndexPath(item: 2, section: 1), animated: false, scrollPosition: .top)
        case .withdrawal:
            collectionView.selectItem(at: IndexPath(item: 3, section: 1), animated: false, scrollPosition: .top)
        case .fee:
            collectionView.selectItem(at: IndexPath(item: 4, section: 1), animated: false, scrollPosition: .top)
        case .rebate:
            collectionView.selectItem(at: IndexPath(item: 5, section: 1), animated: false, scrollPosition: .top)
        }
    }
    
    private func updatecollectionViewHeightAndScrollingEnabledIfNeeded() {
        collectionViewHeightConstraint.constant = ceil(collectionView.contentSize.height)
        collectionView.isScrollEnabled = collectionView.contentSize.height >= collectionView.frame.height
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
