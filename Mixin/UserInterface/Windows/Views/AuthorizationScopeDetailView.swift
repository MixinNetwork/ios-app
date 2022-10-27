import UIKit
import MixinServices

protocol AuthorizationScopeDetailViewDelegate: AnyObject {
    
    func authorizationScopeDetailViewDidReviewScopes(_ controller: AuthorizationScopeDetailView)
    
}

class AuthorizationScopeDetailView: UIView, XibDesignable {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var layout: SnapCenterFlowLayout!
    
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    weak var delegate: AuthorizationScopeDetailViewDelegate?
    
    private var scopeHandler: AuthorizationScopeHandler!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXibAndSetupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXibAndSetupUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layout.itemSize = CGSize(width: bounds.width - 64, height: collectionViewHeightConstraint.constant)
    }
    
    func render(with scopeHandler: AuthorizationScopeHandler) {
        self.scopeHandler = scopeHandler
        pageControl.numberOfPages = scopeHandler.scopeGroups.count
        collectionView.reloadData()
    }
    
    @IBAction func nextAction(_ sender: Any) {
        let nextPage = pageControl.currentPage + 1
        if nextPage == scopeHandler.scopeGroups.count {
            delegate?.authorizationScopeDetailViewDidReviewScopes(self)
        } else {
            let offset = CGPoint(x: CGFloat(nextPage) * collectionView.frame.width, y: 0)
            collectionView.setContentOffset(offset, animated: true)
        }
    }
    
}

extension AuthorizationScopeDetailView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        scopeHandler.scopeGroups.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.authorization_scope_detail, for: indexPath)!
        cell.render(scopeGroup: scopeHandler.scopeGroups[indexPath.row], scopeHandler: scopeHandler)
        return cell
    }
    
}

extension AuthorizationScopeDetailView: UIScrollViewDelegate, UICollectionViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = scrollView.contentOffset.x / scrollView.frame.width
        pageControl.currentPage = Int(round(page))
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? AuthorizationScopeDetailCell else {
            return
        }
        let tableView = cell.scopeView.tableView
        tableView.layoutIfNeeded()
        let maxHeight: CGFloat
        switch ScreenHeight.current {
        case .short, .medium:
            maxHeight = 192
        case .long:
            maxHeight = 274
        case .extraLong:
            maxHeight = 312
        }
        let height = min(ceil(tableView.contentSize.height), maxHeight)
        tableView.snp.updateConstraints { make in
            make.height.equalTo(height)
        }
    }
    
}

extension AuthorizationScopeDetailView {
    
    private func loadXibAndSetupUI() {
        loadXib()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(R.nib.authorizationScopeDetailCell)
    }
    
}
