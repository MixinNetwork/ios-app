import UIKit
import MixinServices

protocol AssetFilterViewControllerDelegate: AnyObject {
    func assetFilterViewController(_ controller: AssetFilterViewController, didApplySort sort: Snapshot.Sort)
}

class AssetFilterViewController: UIViewController {
    
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var applyButton: RoundedButton!
    
    @IBOutlet weak var titleHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var applyButtonTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var applyButtonBottomConstraint: NSLayoutConstraint!
    
    private var showFilters = false {
        didSet {
            if isViewLoaded {
                collectionView.reloadData()
            }
        }
    }
    
    weak var delegate: AssetFilterViewControllerDelegate?
    
    private(set) var sort = Snapshot.Sort.createdAt
    private(set) var filter = Snapshot.Filter.all
    
    private lazy var sortDraft = sort
    private lazy var filterDraft = filter
    
    private let cellReuseId = "condition"
    private let headerReuseId = "header"
    private var headers: [String] {
        if showFilters {
            return [R.string.localizable.sort_by(),
                    R.string.localizable.filter_by()]
        } else {
            return [R.string.localizable.sort_by()]
        }
    }
    private var titles: [[String]] {
        let sortTitles = [R.string.localizable.time(), R.string.localizable.amount()]
        let filterTitles = [R.string.localizable.all(),
                            R.string.localizable.transfer(),
                            R.string.localizable.deposit(),
                            R.string.localizable.withdrawal(),
                            R.string.localizable.fee(),
                            R.string.localizable.rebate(),
                            R.string.localizable.raw()]
        if showFilters {
            return [sortTitles, filterTitles]
        } else {
            return [sortTitles]
        }
    }
    
    class func instance() -> AssetFilterViewController {
        let vc = R.storyboard.wallet.asset_filter()!
        vc.transitioningDelegate = PopupPresentationManager.shared
        vc.modalPresentationStyle = .custom
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(AssetFilterHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: headerReuseId)
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        reloadSelection()
        view.layoutIfNeeded()
        updateCollectionViewHeightAndScrollingEnabledIfNeeded()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sortDraft = sort
        filterDraft = filter
        reloadSelection()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            DispatchQueue.main.async {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.layoutIfNeeded()
                self.updateCollectionViewHeightAndScrollingEnabledIfNeeded()
            }
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func applyAction(_ sender: Any) {
        sort = sortDraft
        filter = filterDraft
        delegate?.assetFilterViewController(self, didApplySort: sort)
        dismiss(animated: true, completion: nil)
    }
    
}

extension AssetFilterViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return titles[section].count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! AssetFilterConditionCell
        cell.titleLabel.text = titles[indexPath.section][indexPath.row]
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return headers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: headerReuseId, for: indexPath) as! AssetFilterHeaderView
        view.label.text = headers[indexPath.section].uppercased()
        return view
    }
    
}

extension AssetFilterViewController: UICollectionViewDelegate {
    
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

extension AssetFilterViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if section == 0 {
            return UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        } else {
            return .zero
        }
    }
    
}

extension AssetFilterViewController {
    
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
        if showFilters {
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
            case .raw:
                collectionView.selectItem(at: IndexPath(item: 6, section: 1), animated: false, scrollPosition: .top)
            }
        }
    }
    
    private func updateCollectionViewHeightAndScrollingEnabledIfNeeded() {
        preferredContentSize.height = titleHeightConstraint.constant
            + collectionView.contentSize.height
            + applyButtonTopConstraint.constant
            + applyButton.frame.height
            + applyButtonBottomConstraint.constant
            + AppDelegate.current.mainWindow.safeAreaInsets.bottom
        view.layoutIfNeeded()
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
        case 6:
            return .raw
        default:
            return .rebate
        }
    }
    
}
