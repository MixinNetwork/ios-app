import UIKit

class MarketHeaderView: UICollectionReusableView {
    
    enum CategoriesMargin {
        case large
        case medium
    }
    
    protocol Delegate: AnyObject {
        func marketHeaderView(_ view: MarketHeaderView, didSelectSubCategoryAt index: Int)
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    weak var delegate: Delegate?
    
    var categoriesMargin: CategoriesMargin = .medium {
        didSet {
            collectionViewLayout.sectionInset = switch categoriesMargin {
            case .large:
                UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            case .medium:
                UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
            }
        }
    }
    
    var subCategories: [MarketSubCategoryDisplay] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        collectionView.register(R.nib.marketSubCategoryCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.alwaysBounceHorizontal = true
        collectionView.showsHorizontalScrollIndicator = false
    }
    
    func selectSubCategory(at index: Int) {
        collectionView.selectItem(
            at: IndexPath(item: index, section: 0),
            animated: false,
            scrollPosition: []
        )
    }
    
}

extension MarketHeaderView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        subCategories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.market_sub_category, for: indexPath)!
        cell.category = subCategories[indexPath.item]
        return cell
    }
    
}

extension MarketHeaderView: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.marketHeaderView(self, didSelectSubCategoryAt: indexPath.item)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
    
}
