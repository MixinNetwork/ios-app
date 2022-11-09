import UIKit
import MixinServices

protocol AuthorizationScopePreviewViewDelegate: AnyObject {
    
    func authorizationScopePreviewViewDidReviewScopes(_ controller: AuthorizationScopePreviewView)
    
}

class AuthorizationScopePreviewView: UIView, XibDesignable {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var layout: SnapCenterFlowLayout!
    
    weak var delegate: AuthorizationScopePreviewViewDelegate?
    
    var dataSource: AuthorizationScopeDataSource? {
        didSet {
            pageControl.numberOfPages = dataSource?.groups.count ?? 0
            collectionView.reloadData()
        }
    }
    
    private var scopesTableViewIndices: [UITableView: Int] = [:]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    @IBAction func nextAction(_ sender: Any) {
        guard let dataSource else {
            return
        }
        let nextPage = pageControl.currentPage + 1
        if nextPage == dataSource.groups.count {
            Logger.general.debug(category: "Authorization", message: "Will confirm scopes: \(dataSource.selectedScopes.map(\.rawValue))")
            delegate?.authorizationScopePreviewViewDidReviewScopes(self)
        } else {
            let offset = CGPoint(x: CGFloat(nextPage) * collectionView.frame.width, y: 0)
            collectionView.setContentOffset(offset, animated: true)
        }
    }
    
    private func loadSubviews() {
        loadXib()
        collectionView.register(R.nib.authorizationScopeGroupCell)
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
}

extension AuthorizationScopePreviewView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource?.groups.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.authorization_scope_group, for: indexPath)!
        guard let group = dataSource?.groups[indexPath.item] else {
            return cell
        }
        cell.imageView.image = group.icon
        cell.titleLabel.text = group.title
        scopesTableViewIndices[cell.tableView] = indexPath.item
        cell.tableView.dataSource = self
        cell.tableView.delegate = self
        cell.tableView.reloadData()
        let maxHeight: CGFloat
        switch ScreenHeight.current {
        case .short, .medium:
            maxHeight = 192
        case .long:
            maxHeight = 274
        case .extraLong:
            maxHeight = 312
        }
        cell.tableView.layoutIfNeeded()
        let height = min(ceil(cell.tableView.contentSize.height), maxHeight)
        cell.tableViewHeightConstraint.constant = height
        return cell
    }
    
}

extension AuthorizationScopePreviewView: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == collectionView else {
            return
        }
        let page = scrollView.contentOffset.x / scrollView.frame.width
        pageControl.currentPage = Int(round(page))
    }
    
}

extension AuthorizationScopePreviewView: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: collectionView.frame.width - layout.sectionInset.horizontal,
               height: collectionView.frame.height - collectionView.contentInset.vertical - layout.sectionInset.vertical)
    }
    
}

extension AuthorizationScopePreviewView: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let groupIndex = scopesTableViewIndices[tableView] else {
            return 0
        }
        return dataSource?.groupedScopes[groupIndex].count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.authorization_scope_list, for: indexPath)!
        if let dataSource, let groupIndex = scopesTableViewIndices[tableView] {
            let scope = dataSource.groupedScopes[groupIndex][indexPath.row]
            cell.titleLabel.text = scope.title
            cell.descriptionLabel.text = scope.description
            if dataSource.arbitraryScopes.contains(scope) {
                cell.checkmarkView.status = .nonSelectable
            } else if dataSource.selectedScopes.contains(scope) {
                cell.checkmarkView.status = .selected
            } else {
                cell.checkmarkView.status = .deselected
            }
        }
        return cell
    }
    
}

extension AuthorizationScopePreviewView: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let dataSource, let groupIndex = scopesTableViewIndices[tableView] else {
            return
        }
        guard let cell = tableView.cellForRow(at: indexPath) as? AuthorizationScopeCell else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: false)
        let scope = dataSource.groupedScopes[groupIndex][indexPath.row]
        let wasSelected = dataSource.selectedScopes.contains(scope)
        if wasSelected {
            if dataSource.deselect(scope: scope) {
                cell.checkmarkView.status = .deselected
            }
        } else {
            dataSource.select(scope: scope)
            cell.checkmarkView.status = .selected
        }
    }
    
}
